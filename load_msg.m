function [msg, msg_bin, p] = load_msg()
msg = ['Shall I compare thee to a summer''s day?'...
    newline 'Thou art more lovely and more temperate:'...
    newline 'Rough winds do shake the darling buds of May,'...
    newline 'And summer''s lease hath all too short a date:'...
    newline 'Sometime too hot the eye of heaven shines,'...
    newline 'And often is his gold complexion dimm''d;'...
    newline 'And every fair from fair sometime declines,'...
    newline 'By chance or nature''s changing course untrimm''d;'...
    newline 'But thy eternal summer shall not fade'...
    newline 'Nor lose possession of that fair thou owest;'...
    newline 'Nor shall Death brag thou wander''st in his shade,'...
    newline 'When in eternal lines to time thou growest:'...
    newline 'So long as men can breathe or eyes can see,'...
    newline 'So long lives this and this gives life to thee.'];
    
 p = [];
    msg_bin = [];
    for i = 1:length(msg)
        msg_bin = [msg_bin, 0];
        encode_dig = str2num(reshape(dec2bin(double(msg(i)),7).',[],1));
        msg_bin = [msg_bin encode_dig'];
        if mod(sum(encode_dig),2) % parity
            msg_bin = [msg_bin 1];
            p = [p 1];
        else
            msg_bin = [msg_bin 0];
            p = [p 0];
        end
        msg_bin = [msg_bin, 1, 1];
    end
end