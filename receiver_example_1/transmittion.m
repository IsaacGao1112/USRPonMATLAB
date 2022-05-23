
clc;
%对付自动生成代码，按esc就好了
tx = comm.SDRuTransmitter( ...
    'Platform','X310', ...
    'IPAddress','192.168.10.2', ...
    'MasterClockRate',200e6, ...
    'InterpolationFactor',200, ...
    'Gain',8, ...
    'CenterFrequency',1.8e9, ...
    'TransportDataType','int16');
sinewave = dsp.SineWave(1,30e3);%幅值为1，频率30K
sampleRate = tx.MasterClockRate/tx.InterpolationFactor;
sinewave.SampleRate = sampleRate;%采样率1MHz
%然后其实sin周期1/30K 一次采样时间1/1M
%那么一个周期需要的点数就是1/30K / 1/1M = 33.33
%那么每33个点就是一个周期
sinewave.SamplesPerFrame = 5e4;
sinewave.OutputDataType = 'double';
sinewave.ComplexOutput = true;
%step就是把上面的配置，给真实的变成信号
%然后这里设定帧长是5e4，就是50000
%然后根据之前的算法的话，可以用plot(real(data(1:34)))
%验证数据是否准确
data = step(sinewave);
frameDuration = (sinewave.SamplesPerFrame)/(sinewave.SampleRate);
time = 0;
%timeSpan的4/30e3就表示了，我只显示4/30e3秒
%然后结合我的采样率，就会自动算出来我显示的有多少个点
%于是乎显示的长度与帧长50e4无关
%property的意思就是根据TimeSpan划定时域，否则用auto就是根据数据长度自定义
timeScope = timescope('TimeSpanSource','property','TimeSpan',4/30e3, ...
    'SampleRate',sampleRate);
timeScope(data);

spectrumScope = dsp.SpectrumAnalyzer('SampleRate',sampleRate);
spectrumScope(data);

release(tx);
