#while `true`; do gcc_color sh -c "cat $PWD/build_output.old >&2"; sleep 1; done
while `true`; do sh -c "cat $PWD/build_output.old >&2"; sleep 1; done
