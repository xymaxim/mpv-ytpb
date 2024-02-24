build:
	fennel -c --require-as-include --skip-include mp,mp.options,mp.input \
		ytpb.fnl > ytpb.lua
