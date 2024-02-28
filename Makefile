build:
	fennel -c --require-as-include \
		--skip-include mp,mp.input,mp.msg,mp.options,mp.utils \
		ytpb.fnl > ytpb.lua
