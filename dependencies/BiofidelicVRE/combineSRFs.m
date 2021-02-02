function newsrf=combineSRFs(srf1,srf2)
%combines two srfs into a single srf structure
%
%David Page
%david.page@utah.edu
%(208)403-6191

newsrf=struct();
newsrf.info=struct('Note_s',['This SRF file was created by merging two srf files which were originally created on the following dates: ', num2str(round(srf1.info.fileCreationDateTime_t)),' and ',num2str(round(srf2.info.fileCreationDateTime_t)),', respectively. See original srf files for header information.']);
newsrf.input=[srf1.input;srf2.input];
newsrf.output=[srf1.output;srf2.output];