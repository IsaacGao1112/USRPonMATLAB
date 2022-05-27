# USRP README

### FM接收机案例

因为实验室的X310中心频点仅支持1.14G-6.06G，因此对于FM的百兆是不支持的，所以用不了

### 根目录的X310specification

这个其实是调用了info(radio)(其中radio是comm.SDRuReceiver或者Transmitter的对象)，生成了关于X310这个USRP的配置表

里面记录了最大最小中心频点，最大最小增益和步长等的

