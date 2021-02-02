function [xhat] = kalman_testSS(xhat,z,TRAIN)

xhatm = TRAIN.A*xhat; 
xhat = xhatm+TRAIN.K*(z-TRAIN.H*xhatm);
 