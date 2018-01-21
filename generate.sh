#! /bin/sh

p5_vendorbin=`perl -MConfig -le 'print $Config{vendorbinexp}'`
if [ "x$p5_vendorbin" != "x" -a -e "$p5_vendorbin" ]; then
        PATH="$p5_vendorbin:$PATH"
        export PATH
fi
p5_sitebin=`perl -MConfig -le 'print $Config{sitebinexp}'`
if [ "x$p5_sitebin" != "x" -a -e "$p5_sitebin" ]; then
        PATH="$p5_sitebin:$PATH"
        export PATH
fi

YAPP=${YAPP:-yapp}

mkdir -p lib/Parse/Kalex
$YAPP -v -m Parse::Kalex::Parser -o lib/Parse/Kalex/Parser.pm kalex.y
