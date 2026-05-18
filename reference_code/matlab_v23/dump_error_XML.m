function outstr = dump_error_XML(errorString);

% the following is scheme to dump errors in appropriate XML format

outstr = '<calcs_v22_age_data><exposureAgeResult>';
outstr = [outstr '<t10St>0</t10St><delt10_int_St>0</delt10_int_St>0<delt10_ext_St>0</delt10_ext_St>'];
outstr = [outstr '<t10Lm>0</t10Lm><delt10_int_Lm>0</delt10_int_Lm>0<delt10_ext_Lm>0</delt10_ext_Lm>'];
outstr = [outstr '<t26St>0</t26St><delt26_int_St>0</delt26_int_St>0<delt26_ext_St>0</delt26_ext_St>'];
outstr = [outstr '<t26Lm>0</t26Lm><delt26_int_Lm>0</delt26_int_Lm>0<delt26_ext_Lm>0</delt26_ext_Lm>'];
outstr = [outstr '</exposureAgeResult>'];

outstr = [outstr '<diagnostics>' errorString '</diagnostics>'];

outstr = [outstr '</calcs_v22_age_data>'];