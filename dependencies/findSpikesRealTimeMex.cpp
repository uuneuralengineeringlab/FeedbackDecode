#include "mex.h"
#include "matrix.h"
#include <math.h>

/*
 *
 *function [ tsCount, ts, newpreviousts, wf ] = findSpikesRealTimeMex( data, threshold, previousts, bufferstartts )
 *
 * Inputs
 *
 *  data        -   A nSample by nChannel double precision matrix containing
 *                  raw time samples of requiring spike detection
 *
 *  threshold   -   A nChannel element double precision vector containing
 *                  threshold values for each channel. Values can be either
 *                  positive or negative. Values of zero are treated as there
 *                  being no threshold. Note: an event is considered to have
 *                  occurred if the threshold is met or exceeded.
 *
 *  previousts  -   A nChannel element double precision vector containing
 *                  the offset to the end of the last detected event from
 *                  preceding cycle of the detection. If the offset is before
 *                  the start of this cycle of the detection, this value
 *                  have been set to zero. No check of that is made. On the
 *                  first call of this routine, this variable should be
 *                  initialized to zero.
 *
 *  bufferstartts   -   A scalar double precision variable containing the 
 *                      time stamp value of the beginning of this block of
 *                      data. All reported time stamps are adjusted by this
 *                      starting point.
 *
 * Outputs
 *
 *  tsCount     -   A nChannel by 1 double precision vector containing the 
 *                  number of events found in this block of data.
 *
 *  ts          -   A M by nChannel double precision matrix containing the 
 *                  time stamp of all detected events, where the time stamp
 *                  value is at the location of the first value that meets
 *                  of exceeds the threshold. The value of M is the maximum
 *                  number of possible timestamps, given the number of 
 *                  time samples (nSample) and the length of the refractory
 *                  period (skipOnThreshold in the magic numbers). All saved
 *                  time stamp values are adjusted by the value of 
 *                  bufferstartts. This matrix is initialized to zero, so it
 *                  might be difficult to interpret an event occurring at
 *                  the very first sample of the buffer (with bufferstartts
 *                  set to zero. However, tsCount provides information regarding
 *                  the number of valid time stamps.
 *
 *  newpreviousts   -   A nChannel by 1 double precision vector containing
 *                      the offset to the end of the last detected event in
 *                      the present cycle of the detection. If the offset is
 *                      before the end of this cycle, the offset is set to
 *                      zero. If the offset is after the end of this cycle,
 *                      this is the location where to begin checking on the
 *                      next cycle. This vector is initialized to zero and
 *                      only overwritten with non-zero values.
 *
 *  wf          -   A fixed size (skipOnThreshold in the magic numbers) by
 *                  nChannel double precision matrix containing waveforms
 *                  of detected events. To preserve space, only one waveform
 *                  per channel is saved. Typically, this is the waveform of
 *                  the first detected event but if the first detected
 *                  event occurs early enough in the buffer that part of 
 *                  the waveform is not contained within the buffer, the
 *                  second detected waveform is written to the buffer,
 *                  even if the event occurs so late that the end of the
 *                  waveform occurs after the end of the buffer. (This is
 *                  a location for some logic improvement.) The entire matrix
 *                  is initialized to NaN and only waveform values in the
 *                  current buffer are written into the matrix.
 *
 * % Creates timestamps for positive threshold crossings that are separated by
 * % at least 52 samples (1.7 ms). The 1st valid waveform is returned.
 * %
 * % $DateTimeTZ: 2015/06/12 14:29:54 -0600 Mountain Daylight Time $
 * % $Author: WarrenDJ $
 */

/* The gateway function */
void mexFunction( int numberOutputArguments, mxArray *pointerOutputArguments[],
        int numberInputArguments, const mxArray *pointerInputArguments[] )
{
    
    /* Magic numbers */
    const int expectednumberInputArguments = 4;
    const int expectednumberOutputArguments = 4;
    const int skipOnThreshold = 52;
    const int prethreshold = 15;
    const int postthreshold = skipOnThreshold - prethreshold -1;
    int nIndex; // Easier why to assure all indices are same
    
    /* Check argument count */
    if( numberInputArguments != expectednumberInputArguments ) {
        mexErrMsgIdAndTxt( "findSpikesRealTimeMex:inputArgumentCountError",
                "Wrong number of input arguments (need 4)." );
    }
    if( numberOutputArguments != expectednumberOutputArguments) {
        mexErrMsgIdAndTxt( "findSpikesRealTimeMex:outputArgumentCountError",
                "Wrong number of output arguments (need 4)." );
    }
    
    /* make sure the first input argument (data) is double matrix */
    nIndex = 0;
    mxAssert( ( pointerInputArguments[nIndex] != NULL ),
            "First argument is null pointer" );
    const mwSize * dataDim = mxGetDimensions( pointerInputArguments[nIndex] );
    const mwSize dataNumDim = mxGetNumberOfDimensions( pointerInputArguments[nIndex] );
    if(
            !mxIsDouble( pointerInputArguments[nIndex] ) ||
            mxIsComplex( pointerInputArguments[nIndex] ) ||
            ( dataNumDim != 2 ) ||
            ( dataDim[0] == 1 ) ||
            ( dataDim[1] == 1 )
            ) {
        mexErrMsgIdAndTxt( "findSpikesRealTimeMex:inputArgumentType",
                "data must be a double matrix" );
    }
    const int nSamples = (int) dataDim[0];
    const int nChannels = (int) dataDim[1];
    const double * const dataPtr = mxGetPr( pointerInputArguments[nIndex] );
#ifdef DEBUGmexPrintf
    mexPrintf( "data size is %d by %d\n", nSamples, nChannels );
#endif
    
    /* make sure the second input argument is double vector */
    nIndex = 1;
    mxAssert( ( pointerInputArguments[nIndex] != NULL ),
            "Second argument is null pointer" );
    const size_t thresholdNumElements = mxGetNumberOfElements( pointerInputArguments[nIndex] );
    if(
            !mxIsDouble( pointerInputArguments[nIndex] ) ||
            mxIsComplex( pointerInputArguments[nIndex] ) ||
            ( thresholdNumElements != nChannels )
            ) {
        mexErrMsgIdAndTxt( "findSpikesRealTimeMex:inputArgumentType",
                "threshold must be a double vector" );
    }
    const double * const thresholdPtr = mxGetPr( pointerInputArguments[nIndex] );
#ifdef DEBUGmexPrintf
    mexPrintf( "threshold size is %d\n", thresholdNumElements );
#endif
    
    /* make sure the third input argument is double vector */
    nIndex = 2;
    mxAssert( ( pointerInputArguments[nIndex] != NULL ),
            "Third argument is null pointer" );
    const size_t previoustsNumElements = mxGetNumberOfElements( pointerInputArguments[nIndex] );
    if(
            !mxIsDouble( pointerInputArguments[nIndex] ) ||
            mxIsComplex( pointerInputArguments[nIndex] ) ||
            ( previoustsNumElements != nChannels )
            ) {
        mexErrMsgIdAndTxt( "findSpikesRealTimeMex:inputArgumentType",
                "previousts must be a double vector" );
    }
    const double * const previoustsPtr = mxGetPr( pointerInputArguments[nIndex] );
#ifdef DEBUGmexPrintf
    mexPrintf( "previousts size is %d\n", previoustsNumElements );
#endif
    
    /* make sure the third input argument is double vector */
    nIndex = 3;
    const size_t bufferstarttsNumElements = mxGetNumberOfElements( pointerInputArguments[nIndex] );
    mxAssert( ( pointerInputArguments[nIndex] != NULL ),
            "Fourth argument is null pointer" );
    if(
            !mxIsDouble( pointerInputArguments[nIndex] ) ||
            mxIsComplex( pointerInputArguments[nIndex] ) ||
            ( bufferstarttsNumElements != 1 )
            ) {
        mexErrMsgIdAndTxt( "findSpikesRealTimeMex:inputArgumentType",
                "bufferstartts must be a double scalar" );
    }
    const double bufferstartts = *mxGetPr( pointerInputArguments[nIndex] );
#ifdef DEBUGmexPrintf
    mexPrintf( "bufferstartts is %f\n", bufferstartts );
#endif
    
    /* create output variables */
    
    /* create output of vector of time stamp counts */
    nIndex = 0;
#ifdef DEBUGmexPrintf
    mexPrintf( "Creating first output variable\n" );
#endif
    pointerOutputArguments[nIndex] = mxCreateDoubleMatrix( nChannels, 1, mxREAL );
    mxAssert( ( pointerOutputArguments[nIndex] != NULL ),
            "First output argument is null pointer" );
    double * const tsCntPtr = mxGetPr( pointerOutputArguments[nIndex] );
    
    /* create output of matrix of time stamp values, time by channel organization */
    nIndex = 1;
    const int maxTS = (int)( ceil( ( (double) nSamples ) / ( (double) skipOnThreshold ) ) ); // Maximum number of possible time stamps
#ifdef DEBUGmexPrintf
    mexPrintf( "Creating second output variable\n" );
#endif
    pointerOutputArguments[nIndex] = mxCreateDoubleMatrix( maxTS, nChannels, mxREAL );
    mxAssert( ( pointerOutputArguments[nIndex] != NULL ),
            "Second output argument is null pointer" );
    double * const tsPtr = mxGetPr( pointerOutputArguments[nIndex] );
    
    /* create output of vector of last time stamp values */
    nIndex = 2;
#ifdef DEBUGmexPrintf
    mexPrintf( "Creating third output variable\n" );
#endif
    pointerOutputArguments[nIndex] = mxCreateDoubleMatrix( nChannels, 1,  mxREAL );
    mxAssert( ( pointerOutputArguments[nIndex] != NULL ),
            "Third output argument is null pointer" );
    double * const newprevioustsPtr = mxGetPr( pointerOutputArguments[nIndex] );
    
    /* create output of matrix of first waveform values, time by channel organization */
    nIndex = 3;
#ifdef DEBUGmexPrintf
    mexPrintf( "Creating Fourth output variable\n" );
#endif
    pointerOutputArguments[nIndex] = mxCreateDoubleMatrix( skipOnThreshold, nChannels,  mxREAL );
    mxAssert( ( pointerOutputArguments[nIndex] != NULL ),
            "Fourth output argument is null pointer" );
    double * const wfPtr = mxGetPr( pointerOutputArguments[nIndex] );
    
    /* variable declarations here */
    const double * dataPtrStart; // Start of a row of data
    const double * dataPtrEnd; // End of a row of data
    const double * dataPtrWork; // Working pointer to data
    const double * thresholdPtrWork; // Working pointer to threshold
    const double * previoustsPtrWork; // Working pointer to previous cycles' last time stamp, adjust to starting index in this cycle
    double * tsCntPtrWork; // Working pointer to TS count
    double * tsPtrWork; // Working pointer to ts value
    double * newprevioustsPtrWork; // Working pointer to this cycles' last time stamp, adjust to starting index in next cycle
    double * wfPtrWork; // Working pointer to waveform
    int wfSaved = 0;
    int m=0;
    int n=0;
    int ch=0;
    int sample=0;
    int startingIndex=0;
    const double NaNValue = mxGetNaN();
    
    /* code here */
    for( n=0, wfPtrWork = wfPtr; n < ( skipOnThreshold*nChannels ); n++ )
    { 
        mxAssert( !( wfPtrWork < (wfPtr) ),
                "Waveform pointer before buffer" );
        mxAssert( !( wfPtrWork > (wfPtr + (nChannels)*skipOnThreshold - 1) ),
                "Waveform after buffer" );
        
        *wfPtrWork++ = NaNValue;
    }
    
    for( ch = 0, dataPtrStart = dataPtr, dataPtrEnd = (dataPtr + nSamples - 1), thresholdPtrWork = thresholdPtr, previoustsPtrWork = previoustsPtr, tsCntPtrWork = tsCntPtr, newprevioustsPtrWork = newprevioustsPtr;
    ch < nChannels;
    ch++, dataPtrStart += nSamples, dataPtrEnd += nSamples, thresholdPtrWork++, previoustsPtrWork++, tsCntPtrWork++, newprevioustsPtrWork++ )
    {
        tsPtrWork = tsPtr + ch*maxTS;
        wfPtrWork = wfPtr + ch*skipOnThreshold;
        startingIndex = (int) ( (*previoustsPtrWork) + 0.5 );
#ifdef DEBUGmexPrintfThreshold
        mexPrintf( "Channel %d, starting at sample %d\n", (ch+1), (startingIndex+1) );
#endif
        wfSaved = 0;
#ifdef DEBUGmexPrintfThreshold
        int nCount = 0;
#endif
        
        mxAssert( !( ch < 0 ),
                "Channel count negative" );
        mxAssert( !( ch > nChannels ),
                "Channel count larger than available channels" );
        
        mxAssert( !( dataPtrStart < dataPtr ),
                "Starting data pointer before buffer" );
        mxAssert( !( dataPtrStart > (dataPtr+nChannels*nSamples) ),
                "Starting data pointer after buffer" );
        
        mxAssert( !( dataPtrEnd < dataPtr ),
                "Ending data pointer before buffer" );
        mxAssert( !( dataPtrEnd > (dataPtr+nChannels*nSamples) ),
                "Ending data pointer after buffer" );
        
        mxAssert( !( thresholdPtrWork < thresholdPtr ),
                "Threshold pointer before buffer" );
        mxAssert( !( thresholdPtrWork > (thresholdPtr+nChannels) ),
                "Threshold pointer after buffer" );
        
        mxAssert( !( previoustsPtrWork < previoustsPtr ),
                "Previous cycle last time stamp pointer before buffer" );
        mxAssert( !( previoustsPtrWork > (previoustsPtr+nChannels) ),
                "Previous cycle last time stamp pointer after buffer" );
        
        mxAssert( !( tsCntPtrWork < tsCntPtr ),
                "TS counter pointer before buffer" );
        mxAssert( !( tsCntPtrWork > (tsCntPtr+nChannels) ),
                "TS counter pointer after buffer" );
        
        mxAssert( !( tsPtrWork < (tsPtr + ch*maxTS) ),
                "TS values pointer before buffer" );
        mxAssert( !( tsPtrWork > (tsPtr + (ch+1)*maxTS - 1) ),
                "TS values pointer after buffer" );
        
        mxAssert( !( newprevioustsPtrWork < newprevioustsPtr ),
                "New previous TS value pointer before buffer" );
        mxAssert( !( newprevioustsPtrWork > (newprevioustsPtr+nChannels) ),
                "New previous TS value after buffer" );
        
        mxAssert( !( startingIndex < 0 ),
                "Starting index negative" );
        mxAssert( !( startingIndex > skipOnThreshold ),
                "Starting index too far into buffer" );
        
        mxAssert( !( wfPtrWork < (wfPtr + ch*skipOnThreshold) ),
                "Waveform pointer before buffer" );
        mxAssert( !( wfPtrWork > (wfPtr + (ch+1)*skipOnThreshold - 1) ),
                "Waveform after buffer" );
        
        if( *thresholdPtrWork < 0 ) { // Start negative threshold
            for( sample = startingIndex, dataPtrWork = dataPtrStart + startingIndex; ( sample < nSamples ); )
            {
                
                mxAssert( !( sample < 0 ),
                        "Sample index negative" );
                mxAssert( !( sample > nSamples ),
                        "Sample index past buffer" );
                
                mxAssert( !( dataPtrWork < dataPtrStart ),
                        "Working data pointer before buffer" );
                mxAssert( !( dataPtrWork > dataPtrEnd ),
                        "Working data pointer after buffer" );
                
                mxAssert( !( tsPtrWork < (tsPtr + ch*maxTS) ),
                        "TS values pointer before buffer" );
                mxAssert( !( tsPtrWork > (tsPtr + (ch+1)*maxTS - 1) ),
                        "TS values pointer after buffer" );
                
                if( *dataPtrWork <= *thresholdPtrWork ) // Only line unique to this block for positive thresholds
                {
#ifdef DEBUGmexPrintfThreshold
                    nCount++;
                    mexPrintf( "Found crossing on channel %d, at sample %d, crossing %d of %d\n", (ch+1), (sample+1), nCount, maxTS );
                    mexPrintf( "Value of %f exceeds threshold of %f\n", *dataPtrWork, *thresholdPtrWork );
#endif
                    // Found crossing, save it all
                    (*tsCntPtrWork)++; // Increment count of ts
                    *tsPtrWork++ = (sample + bufferstartts); // Add ts to matrix, correcting for buffer initial ts
                    *newprevioustsPtrWork = (double) ((sample+skipOnThreshold) - nSamples ); // Where to start on the next cycle
                    if( *newprevioustsPtrWork < 0 ){*newprevioustsPtrWork = 0;}
#ifdef DEBUGmexPrintfThreshold
                    mexPrintf( "Channel %d, at sample %d, next loop start at %f \n", (ch+1), (sample+1), (*newprevioustsPtrWork) + 1 );
#endif
                    // Save waveform
                    if( wfSaved < 2 )
                    {
                        wfSaved = 2;
                        for( n = 0, nIndex = (sample - prethreshold); n < skipOnThreshold; n++, nIndex++ )
                        {
                            
                            mxAssert( !( n < 0 ),
                                    "WF index negative" );
                            mxAssert( !( n > skipOnThreshold ),
                                    "WF index past buffer" );
                            
                            mxAssert( !( (wfPtrWork + n) < (wfPtr + ch*skipOnThreshold) ),
                                    "Waveform pointer before buffer" );
                            mxAssert( !( (wfPtrWork + n) > (wfPtr + (ch+1)*skipOnThreshold - 1) ),
                                    "Waveform after buffer" );
                            
                            if( nIndex < 0 )
                            {
                                wfSaved = 1;
                                *(wfPtrWork + n) = NaNValue;
                            }
                            else if( nIndex >= nSamples )
                            {
                                // wfSaved = 2; // default, no need to enforce
                                *(wfPtrWork + n) = NaNValue;
                            }
                            else
                            {
                                mxAssert( !( (dataPtrStart + nIndex) < dataPtrStart ),
                                        "Working data pointer before buffer" );
                                mxAssert( !( (dataPtrStart + nIndex) > dataPtrEnd ),
                                        "Working data pointer after buffer" );
                                *(wfPtrWork + n) = *(dataPtrStart + nIndex );
                            }
                        }
                    }
                    dataPtrWork += skipOnThreshold; // skip over refractory period
                    sample += skipOnThreshold; // skip over refractory period
                }
                else
                {
                    dataPtrWork++; // Simple iterate
                    sample++; // Simple iterate
                }
            }
        } // End negative threshold
        else if( *thresholdPtrWork > 0 ) { // Start positive threshold
            for( sample = startingIndex, dataPtrWork = dataPtrStart + startingIndex; ( sample < nSamples ); )
            {
                
                mxAssert( !( sample < 0 ),
                        "Sample index negative" );
                mxAssert( !( sample > nSamples ),
                        "Sample index past buffer" );
                
                mxAssert( !( dataPtrWork < dataPtrStart ),
                        "Working data pointer before buffer" );
                mxAssert( !( dataPtrWork > dataPtrEnd ),
                        "Working data pointer after buffer" );
                
                mxAssert( !( tsPtrWork < (tsPtr + ch*maxTS) ),
                        "TS values pointer before buffer" );
                mxAssert( !( tsPtrWork > (tsPtr + (ch+1)*maxTS - 1) ),
                        "TS values pointer after buffer" );
                
                if( *dataPtrWork >= *thresholdPtrWork )  // Only line unique to this block for positive thresholds
                {
#ifdef DEBUGmexPrintfThreshold
                    nCount++;
                    mexPrintf( "Found crossing on channel %d, at sample %d, crossing %d of %d\n", (ch+1), (sample+1), nCount, maxTS );
                    mexPrintf( "Value of %f exceeds threshold of %f\n", *dataPtrWork, *thresholdPtrWork );
#endif
                    // Found crossing, save it all
                    (*tsCntPtrWork)++; // Increment count of ts
                    *tsPtrWork++ = (sample + bufferstartts); // Add ts to matrix, correcting for buffer initial ts
                    *newprevioustsPtrWork = (double) ((sample+skipOnThreshold) - nSamples ); // Where to start on the next cycle
                    if( *newprevioustsPtrWork < 0 ){*newprevioustsPtrWork = 0;}
#ifdef DEBUGmexPrintfThreshold
                    mexPrintf( "Channel %d, at sample %d, next loop start at %f \n", (ch+1), (sample+1), (*newprevioustsPtrWork) + 1 );
#endif
                    // Save waveform
                    if( wfSaved < 2 )
                    {
                        wfSaved = 2;
                        for( n = 0, nIndex = (sample - prethreshold); n < skipOnThreshold; n++, nIndex++ )
                        {
                            
                            mxAssert( !( n < 0 ),
                                    "WF index negative" );
                            mxAssert( !( n > skipOnThreshold ),
                                    "WF index past buffer" );
                            
                            mxAssert( !( (wfPtrWork + n) < (wfPtr + ch*skipOnThreshold) ),
                                    "Waveform pointer before buffer" );
                            mxAssert( !( (wfPtrWork + n) > (wfPtr + (ch+1)*skipOnThreshold - 1) ),
                                    "Waveform after buffer" );
                            
                            if( nIndex < 0 )
                            {
                                wfSaved = 1;
                                *(wfPtrWork + n) = NaNValue;
                            }
                            else if( nIndex >= nSamples )
                            {
                                // wfSaved = 2; // default, no need to enforce
                                *(wfPtrWork + n) = 0;
                            }
                            else
                            {
                                mxAssert( !( (dataPtrStart + nIndex) < dataPtrStart ),
                                        "Working data pointer before buffer" );
                                mxAssert( !( (dataPtrStart + nIndex) > dataPtrEnd ),
                                        "Working data pointer after buffer" );
                                *(wfPtrWork + n) = *(dataPtrStart + nIndex );
                            }
                        }
                    }
                    dataPtrWork += skipOnThreshold; // skip over refractory period
                    sample += skipOnThreshold; // skip over refractory period
                }
                else
                {
                    dataPtrWork++; // Simple iterate
                    sample++; // Simple iterate
                }
            }
        } // End positive threshold
    }
}