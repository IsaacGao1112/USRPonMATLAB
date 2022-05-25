clear;

rx = comm.SDRuReceiver('Platform','X310', ...
    'IPAddress','192.168.10.2', ...
    'OutputDataType','double', ...
    'ChannelMapping',2, ...
    'MasterClockRate',200e6, ...
    'DecimationFactor',200, ...
    'Gain',30, ...
    'CenterFrequency',1.8e9, ...
    'SamplesPerFrame',5e4);
sampleRate = rx.MasterClockRate/rx.DecimationFactor;
frameDuration = (rx.SamplesPerFrame)/sampleRate;
time = 0;
timeScope = timescope('TimeSpanSource','property','TimeSpan',4/30e3,'SampleRate',sampleRate);

% spectrumScope = dsp.SpectrumAnalyzer('SampleRate',sampleRate);
% spectrumScope.ReducePlotRate = true;

disp('start receiving');
while time<30
    data = rx();
    amp = max(abs(data));
    data_FFT = fft(data);
    timeScope([real(data),imag(data)]);
%     spectrumScope(data);
    time = time+frameDuration;

end

release(timeScope);
release(spectrumScope);
release(rx);