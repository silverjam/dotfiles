while `true`; do ninja -j160 -C out/Debug chrome | tee build_output; cp build_output build_output.old; done
