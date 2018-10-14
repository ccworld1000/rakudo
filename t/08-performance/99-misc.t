use Test;

plan 4;

# https://github.com/rakudo/rakudo/issues/1488
{
    my class Foo {
        method Stringy {
            die "missed optimization"
        }
    };
    my $f := Foo.new;
    is-deeply $f cmp ($ = $f), Same, 'eqaddr optimization for cmp exists'
}

{
    my int @a = ^2_000_000;
    my $then = now;
    my $result1 = @a.sum;
    my $took1 = now - $then;

    $then = now;
    my $result2 = @a.sum(:wrap);
    my $took2 = now - $then;

    is $result1, $result2, "is $result1 == $result2";
    ok $took2 < $took1 / 20,
        "was native .sum $took2 at least 20x as fast as $took1 ({$took1/$took2}x)";
}

{ # https://github.com/rakudo/rakudo/issues/1740
    my $t-plain = { (^∞).grep(*.is-prime)[1000];       now - ENTER now }();
    my $t-hyper = { (^∞).hyper.grep(*.is-prime)[1000]; now - ENTER now }();
    cmp-ok $t-hyper, '≤', $t-plain*2,
        'hypered .grep .is-prime is not hugely slower than plain grep';
}
