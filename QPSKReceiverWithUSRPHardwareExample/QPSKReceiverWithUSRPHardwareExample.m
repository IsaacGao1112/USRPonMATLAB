%% QPSK Receiver with USRP(TM) Hardware
% This example shows how to use the Universal Software Radio Peripheral(R)
% (USRP(TM)) device using SDRu (Software Defined Radio USRP) System objects
% to implement a QPSK receiver. The receiver addresses practical issues in
% wireless communications, such as carrier frequency and phase offset,
% timing offset and frame synchronization. This system receives the signal
% sent by the <docid:usrpradio_ug#example-sdruQPSKTransmitter QPSK
% Transmitter with USRP® Hardware> example at bit rate of 2 Mbps. The
% receiver demodulates the received symbols and prints a simple message to
% the
% MATLAB(R) command line.
%
% Please refer to the Setup and Configuration section of
% <docid:usrpradio_ug#bue1zea-1 Guided USRP Radio Support Package Hardware
% Setup> for details on configuring your host computer to work with the
% SDRu Receiver System object.
%
% Copyright 2012-2022 The MathWorks, Inc.

%% Implementations
% This example describes the MATLAB implementation of a QPSK receiver with 
% USRP Hardware. There is another implementation of this example that uses 
% Simulink(R).
%
% MATLAB script using System objects:
% <matlab:edit('sdruQPSKReceiver.m') sdruQPSKReceiver.m>.
%
% Simulink implementation using blocks: <matlab:sdruqpskrx sdruqpskrx.mdl>.
%
% You can also explore a simulation only QPSK Transmitter and Receiver
% example without SDR hardware that models a general wireless communication
% system using an AWGN channel and simulated channel impairments at
% <docid:comm_ug#example-commQPSKTransmitterReceiver QPSK Transmitter and Receiver>.

%% Introduction
% This example has the following motivation:
%
% * To implement a real QPSK-based transmission-reception environment in
% MATLAB using SDRu System objects.
%
% * To illustrate the use of key Communications Toolbox(TM) System
% objects for QPSK system design, including coarse and fine carrier
% frequency compensation, timing recovery with bit stuffing and
% stripping, frame synchronization, carrier phase ambiguity resolution, and
% message decoding.
%
% In this example, the SDRuReceiver System object receives data corrupted
% by the transmission over the air at sample rate of 2 Msps and outputs
% complex baseband signals which are processed by the QPSK Receiver System
% object. This example provides a reference design of a practical digital
% receiver that can cope with wireless channel impairments. The receiver
% includes correlation-based coarse frequency compensation, PLL-based fine
% frequency compensation, timing recovery with fixed-rate resampling and
% bit stuffing/skipping, frame synchronization, and phase ambiguity
% resolution.

%% Discover Radio
% Discover radio(s) connected to your computer. This example uses the first
% USRP radio found using the |findsdru| function. Check if the radio is
% available and record the radio type. If no available radios are found,
% the example uses a default configuration for the system.

connectedRadios = findsdru;
if strncmp(connectedRadios(1).Status, 'Success', 7)
  platform = connectedRadios(1).Platform;
  switch connectedRadios(1).Platform
    case {'B200','B210'}
      address = connectedRadios(1).SerialNum;
    case {'N200/N210/USRP2','X300','X310','N300','N310','N320/N321'}
      address = connectedRadios(1).IPAddress;
  end
else
  address = '192.168.10.2';
  platform = 'N200/N210/USRP2';
end

%% Initialization
% The <matlab:edit('sdruqpskreceiver_init.m') sdruqpskreceiver_init.m>
% script initializes the simulation parameters and generates the structure
% _prmQPSKReceiver_.

printReceivedData = false;    % true if the received data is to be printed
compileIt         = false;   % true if code is to be compiled for accelerated execution
useCodegen        = false;   % true to run the latest generated code (mex file) instead of MATLAB code

% Receiver parameter structure
prmQPSKReceiver = sdruqpskreceiver_init(platform, useCodegen)
prmQPSKReceiver.Platform = platform;
prmQPSKReceiver.Address = address;

%%
% To transmit successfully, ensure that the specified center frequency of
% the SDRu Receiver is within the acceptable range of your USRP
% daughterboard.
%
% Also, by using the compileIt and useCodegen flags, you can interact with
% the code to explore different execution options.  Set the MATLAB variable
% compileIt to true in order to generate C code; this can be
% accomplished by using the *codegen* command provided by the MATLAB
% Coder(TM) product. The *codegen* command compiles MATLAB(R) functions to
% a C-based static or dynamic library, executable, or MEX file, producing
% code for accelerated execution. The generated executable runs several times
% faster than the original MATLAB code. Set useCodegen to true to run the
% executable generated by *codegen* instead of the MATLAB code.

%% Code Architecture
% The function runSDRuQPSKReceiver implements the QPSK receiver using
% two System objects, QPSKReceiver and comm.SDRuReceiver. 
%
% *SDRu Receiver*
%
% This example communicates with the USRP board using the SDRu receiver
% System object. The parameter structure _prmQPSKReceiver_ sets the
% CenterFrequency, Gain, and InterpolationFactor etc.
%
% *QPSK Receiver*
%
% This component regenerates the original transmitted message. It is
% divided into five subcomponents, modeled using System objects. Each
% subcomponent is modeled by other subcomponents using System objects.
%
% 1) Automatic Gain Control: Sets its output power to a level ensuring that
% the equivalent gains of the phase and timing error detectors keep
% constant over time. The AGC is placed before the *Raised Cosine Receive
% Filter* so that the signal amplitude can be measured with an oversampling
% factor of two. This process improves the accuracy of the estimate.
%
% 2) Coarse frequency compensation: Uses a correlation-based algorithm to
% roughly estimate the frequency offset and then compensate for it. The
% estimated coarse frequency offset is averaged so that fine frequency
% compensation is allowed to lock/converge. Hence, the coarse frequency
% offset is estimated using a *comm.CoarseFrequencyCompensator* System
% object and an averaging formula; the compensation is performed using a
% *comm.PhaseFrequencyOffset* System object.
%
% 3) Timing recovery: Performs timing recovery with closed-loop scalar
% processing to overcome the effects of delay introduced by the channel,
% using a *comm.SymbolSynchronizer* System object. The object implements a
% PLL to correct the symbol timing error in the received signal. The
% rotationally-invariant Gardner timing error detector is chosen for the
% object in this example; thus, timing recovery can precede fine frequency
% compensation. The input to the object is a fixed-length frame of samples.
% The output of the object is a frame of symbols whose length can vary due
% to bit stuffing and stripping, depending on actual channel delays.
%
% 4) Fine frequency compensation: Performs closed-loop scalar processing
% and compensates for the frequency offset accurately, using a
% *comm.CarrierSynchronizer* System object. The object implements a
% phase-locked loop (PLL) to track the residual frequency offset and the
% phase offset in the input signal.
%
% 5) Preamble Detection: Detects the location of the known Barker code in
% the input using a *comm.PreambleDetector* System object. The object
% implements a cross-correlation based algorithm to detect a known sequence
% of symbols in the input.
%
% 6) Frame Synchronization: Performs frame synchronization and, also,
% converts the variable-length symbol inputs into fixed-length outputs,
% using a *FrameSynchronizer* System object. The object has a secondary
% output that is a boolean scalar indicating if the first frame output is
% valid.
%
% 7) Data decoder: Performs phase ambiguity resolution and demodulation.
% Also, the data decoder compares the regenerated message with the
% transmitted one and calculates the BER.
%
% For more information about the system components, refer to the
% <docid:usrpradio_ug#example-sdruqpskrx QPSK Receiver with USRP®
% Hardware>.

%% Execution and Results
% Before running the script, first turn on the USRP and connect it to
% the computer. To ensure data reception, first start the
% <docid:usrpradio_ug#example-sdruQPSKTransmitter QPSK Transmitter with
% USRP® Hardware> example.

if compileIt
    codegen('runSDRuQPSKReceiver', '-args', {coder.Constant(prmQPSKReceiver), coder.Constant(printReceivedData)});
end
if useCodegen
   clear runSDRuQPSKReceiver_mex %#ok<UNRCH>
   BER = runSDRuQPSKReceiver_mex(prmQPSKReceiver, printReceivedData);
else
   BER = runSDRuQPSKReceiver(prmQPSKReceiver, printReceivedData); 
end

fprintf('Error rate is = %f.\n',BER(1));
fprintf('Number of detected errors = %d.\n',BER(2));
fprintf('Total number of compared samples = %d.\n',BER(3));

%%
% When you run the experiments, the received messages are decoded and
% printed out in the MATLAB command window while the simulation is running.
% BER information is also shown at the end of the script execution. The
% calculation of the BER value only on the message part (Hello world), when
% some of the adaptive components in the QPSK receiver still have not
% converged. During this period, the BER is quite high. Once the
% transient period is over, the receiver is able to estimate the transmitted
% frame and the BER dramatically decreases. In this example, to guarantee a
% reasonable execution time of the system in simulation mode, the
% simulation duration is fairly short. As such, the overall BER results
% are significantly affected by the high BER values at the beginning of the
% simulation. To increase the simulation duration and obtain lower BER
% values,  you can change the SimParams.StopTime variable in the
% <matlab:edit('sdruqpskreceiver_init.m') receiver initialization file>.
%
% Also, the gain behavior of different USRP daughter boards varies
% considerably. Thus, the gain setting in the transmitter and receiver
% defined in this example may not be well-suited for your daughter boards.
% If the message is not properly decoded by the receiver system, you can
% vary the gain of the source signals in the *SDRu Transmitter* and *SDRu
% Receiver* System objects by changing the SimParams.USRPGain value in the
% <matlab:edit('sdruqpsktransmitter_init.m') transmitter initialization
% file> and in the <matlab:edit('sdruqpskreceiver_init.m') receiver
% initialization file>. Besides, preamble detector's threshold also affects
% the decoded message. If you see recurrent garbled messages, please try to
% increase the preamble detector's threshold as the following steps are
% trying to decode the header. If you cannot see any output message, try to
% decrease the threshold in the <matlab:edit('sdruqpskreceiver_init.m') receiver
% initialization file>.
%
% Finally, a large relative frequency offset between the transmit and receive
% USRP radios can prevent the receiver functions from properly decoding
% the message. If that happens, you can determine the offset by sending a
% tone at a known frequency from the transmitter to the receiver, then
% measuring the offset between the transmitted and received frequency, then
% applying that offset to the center frequency of the SDRu Receiver System
% object. Besides, increase the maximum frequency offset in the 
% <matlab:edit('sdruqpskreceiver_init.m') receiver initialization file>
% also helps.

%% Appendix
% This example uses the following script and helper functions:
%
% * <matlab:edit('runSDRuQPSKReceiver.m') runSDRuQPSKReceiver.m>
% * <matlab:edit('sdruqpskreceiver_init.m') sdruqpskreceiver_init.m>
% * <matlab:edit('QPSKReceiver.m') QPSKReceiver.m>

%% References
% 1. Rice, Michael. _Digital Communications - A Discrete-Time
% Approach_. 1st ed. New York, NY: Prentice Hall, 2008.