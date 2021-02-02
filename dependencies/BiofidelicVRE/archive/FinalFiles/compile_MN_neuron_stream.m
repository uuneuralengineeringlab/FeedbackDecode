% compile MN_neuron_stream.m

max_current_length = 125;

codegen MN_neuron_stream -o MN_neuron_stream...
    -args {coder.typeof(double(0),[],1),coder.typeof(double(0),[],1),coder.typeof(double(0),[],1),coder.typeof(double(0),[],1),coder.typeof(double(0),[],1),coder.typeof(double(0),[],1),coder.typeof(double(0),[],1),coder.typeof(double(0),[],1),coder.typeof(double(0),[],1),coder.typeof(double(0),[2 1],[true false]),coder.typeof(double(0),[2 1],[true false]),coder.typeof(double(0),[],1),coder.typeof(double(0),[1 max_current_length],[false true]),coder.typeof(double(0),[2 max_current_length],[true true]),coder.typeof(double(0),[4 1])}

codegen MN_neuron_stream_wrapper -o MN_neuron_stream_wrapper...
    -args {coder.typeof(double(0),[1 13]),coder.typeof(double(0),[4 1]),coder.typeof(double(0),[1 max_current_length*4])}
