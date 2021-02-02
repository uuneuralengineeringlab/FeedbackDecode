
outfile = '\\pnilabview\PNILabview_System\Users\Administrator\Code\Tasks\FeedbackDecode\resources\20150713_set2.txt';
NumTrials = 1;
DOF = [1,2,3,10];
FlexFlag = 2;
ComboFlag = 1;
Endpt = 1;
mDel = 0;
mVel = 1;
HoldTime = 0.3;
RandomizeOrder = 0;
RandomizeEndpt = 0;
RandomizeDelay = 0;
RandomizeVel = 0;
RandomizeHoldTime = 0;
RandomizeSpan = 0;
TrackingFlag = 1;

[outfile, MovementStruct]  = GenerateRandMovementList(outfile, NumTrials, DOF, FlexFlag, ComboFlag, Endpt, mDel,  mVel, HoldTime, RandomizeOrder, RandomizeEndpt,RandomizeDelay, RandomizeVel, RandomizeHoldTime, RandomizeSpan, TrackingFlag);
