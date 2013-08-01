#!/bin/bash

patch=/tmp/pull-request-`git symbolic-ref HEAD | sed s#refs/heads/##`.mkd ;
pattern='``` diff' ;

if [ ! -e "$patch" ]; then #;
    echo 'PULL-REQUEST-TITLE' >>$patch ;
    echo >>$patch ;
else #;
    upto=`tempfile` ;
    awk "{if(\$0 ~ /$pattern/){flag=1} if(flag==0){print \$0}}" $patch >$upto ;
    cp $upto $patch ;
    rm $upto ;
fi #;

echo $pattern >>$patch ;
git format-patch --stdout $1 >>$patch ;
echo '```' >>$patch ;

[ -z "$EDITOR" ] && EDITOR=vi ;
$EDITOR $patch ;

cbr=$(git cbr) ;
org=$(git org) ;

hub pull-request -F $patch -b $org:$1 -h $org:$cbr && rm -f $patch
