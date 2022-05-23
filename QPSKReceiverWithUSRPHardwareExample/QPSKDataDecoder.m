classdef QPSKDataDecoder < matlab.System
    %

    % Copyright 2012-2018 The MathWorks, Inc.
    
    properties (Nontunable)
        ModulationOrder = 4; 
        HeaderLength = 26;
        PayloadLength = 2240;
        NumberOfMessage = 20;
        DescramblerBase = 2;
        DescramblerPolynomial = [1 1 1 0 1];
        DescramblerInitialConditions = [0 0 0 0];
        BerMask = [];
        PrintOption = false;
    end
    
    properties (Access = private)
        pPayloadLength
        pQPSKDemodulator
        pDescrambler
        pErrorRateCalc
        pTargetBits
        pBER
    end
    
    properties (Constant, Access = private)
        pBarkerCode = [+1; +1; +1; +1; +1; -1; -1; +1; +1; -1; +1; -1; +1]; % Bipolar Barker Code
        pModulatedHeader = sqrt(2)/2 * (-1-1i) * QPSKDataDecoder.pBarkerCode;
        pMessage = 'Hello world';
        pMessageLength = 16;
    end
    
    methods
        function obj = QPSKDataDecoder(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access = protected)
        function setupImpl(obj, ~, ~)
            coder.extrinsic('sprintf');
            
            obj.pQPSKDemodulator = comm.QPSKDemodulator('PhaseOffset',pi/4, ...
                'BitOutput', true);
            
            obj.pDescrambler = comm.Descrambler(obj.DescramblerBase, ...
                obj.DescramblerPolynomial, obj.DescramblerInitialConditions);
            
            obj.pErrorRateCalc = comm.ErrorRate( ...
                'Samples', 'Custom', ...
                'CustomSamples', obj.BerMask);
            
            % Since we only calculate BER on message part, 000s are not
            % necessary here, they are just place-holder.
            msgSet = zeros(obj.NumberOfMessage * obj.pMessageLength, 1);
            for msgCnt = 0 : obj.NumberOfMessage - 1
                msgSet(msgCnt * obj.pMessageLength + (1 : obj.pMessageLength)) = ...
                    sprintf('%s %03d\n', obj.pMessage, mod(msgCnt, 100));
            end
            obj.pTargetBits = reshape(de2bi(msgSet, 7, 'left-msb')', [], 1);
        end
        
        function  BER = stepImpl(obj, data, isValid)
            if isValid
                % Phase ambiguity estimation
                phaseEst = round(angle(mean(conj(obj.pModulatedHeader) .* data(1:obj.HeaderLength/2)))*2/pi)/2*pi;
                
                % Compensating for the phase ambiguity
                phShiftedData = data .* exp(-1i*phaseEst);
                
                % Demodulating the phase recovered data
                demodOut = obj.pQPSKDemodulator(phShiftedData);
                
                % Performs descrambling on only payload part
                deScrData = obj.pDescrambler( ...
                    demodOut(obj.HeaderLength + (1 : obj.PayloadLength)));
                
                % Recovering the message from the data
                charSet = int8(bi2de(reshape(deScrData, 7, [])', 'left-msb'));
                if(obj.PrintOption)
                    fprintf('%s', char(charSet));
                end
                
                % Perform BER calculation only on message part
                obj.pBER = obj.pErrorRateCalc(obj.pTargetBits, deScrData);
            end
            BER = obj.pBER;
        end
        
        function resetImpl(obj)
            reset(obj.pQPSKDemodulator);
            reset(obj.pDescrambler);
            reset(obj.pErrorRateCalc);
            obj.pBER = zeros(3, 1);
        end
        
        function releaseImpl(obj)
            release(obj.pQPSKDemodulator);
            release(obj.pDescrambler);
            release(obj.pErrorRateCalc);
            obj.pBER = zeros(3, 1);
        end
    end
end

