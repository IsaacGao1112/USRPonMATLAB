   % Example 2: 
    %   Configure a USRP B210 board with a serial number of ECR04ZDBT to 
    %   transmit at 1 GHz with a interpolation factor of 256.
    clear;

    tx = comm.SDRuTransmitter('Platform','X310',...
           'IPAddress','192.168.10.2');
    tx.CenterFrequency = 4e9;
    tx.InterpolationFactor = 128;%带宽其实等于时钟频率/升采样因子
    %只是现在应该是哪里没做好有泄露，和刚开始双通道没有调通时候的状态是一样的
    tx.MasterClockRate = 184.32e6; %USRP的钟只能是200M或者184.32MHz
    tx.LocalOscillatorOffset = 0;     
    tx.Gain = 20;    %认证 Gain确实是越大信号越强，一直到30都有效
    tx.ChannelMapping = 1;
    info(tx)
    % 可以先用平台和IP找到对应的USRP
    % 成功后可以用info来查询具体可设置的属性
    % 
    modulator = comm.PSKModulator(2,0,'BitInput',true);
    for counter = 1:2000
%       data = randi([0 1], 3000000, 1);
      data = randi([0 1], 3000, 1);
      modSignal = modulator(data);
      underrun = tx(modSignal);
      if(underrun~=0)
          msg = ['underrun detected in frame # ',int2str(counter)];
          disp(msg);
      end

%       step(tx,modSignal);
    end
    %信号的确是发出来了，但是不对，聚集在低频段，波形也并不对
    release(tx);