if [ -e tags ]; then
    echo "Tag file exists"
    exit 1
fi

ctags \
    --exclude=build \
    --exclude=dist \
    -R /usr/lib/python2.7/ \

mv tags ~/.pythontags/tags

    #--python-kinds=-iv `
