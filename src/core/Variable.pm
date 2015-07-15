# for our tantrums
my class X::Comp::NYI { ... };
my class X::Comp::Trait::Unknown { ... };
my class X::Comp::Trait::NotOnNative { ... };
my class X::Comp::Trait::Scope { ... };

# Variable traits come here, not in traits.pm, since we declare Variable
# in the setting rather than BOOTSTRAP.

my class Variable {
    has str $.name;
    has str $.scope;
    has $.var is rw;
    has $.block;
    has $.slash;

    # make throwing easier
    submethod throw ( |c ) {
        $*W.throw( self.slash, |c );
    }

    submethod willdo(&block, $caller-levels = 2) {
        $caller-levels == 2
            ?? -> { block(nqp::atkey(nqp::ctxcaller(nqp::ctxcaller(nqp::ctx())), self.name)) }
            !! -> { block(nqp::atkey(nqp::ctxcaller(nqp::ctx()), self.name)) }
    }
}

# "is" traits
multi sub trait_mod:<is>(Variable:D $v, |c ) {
    $v.throw('X::Comp::Trait::Unknown',
      :type<is>,
      :subtype(c.hash.keys[0]),
      :declaring(' variable'),
      :expected('TypeObject default dynamic'),
    );
}
multi sub trait_mod:<is>(Variable:D $v, Mu:U $is ) {
    $v.throw('X::Comp::NYI', :feature("Variable trait 'is TypeObject'"));
}
multi sub trait_mod:<is>(Variable:D $v, :$default!) {
    my $var  := $v.var;
    my $what := $var.VAR.WHAT;

    my $descriptor;
    try {
        $descriptor := nqp::getattr($var, $what.^mixin_base, '$!descriptor');
        CATCH {
            nqp::istype($default,Whatever)
              ?? $v.throw( 'X::Comp::NYI',
                :feature('is default(*) on natives'))
              !! $v.throw( 'X::Comp::Trait::NotOnNative',
                :type<is>, :subtype<default> ); # can't find out native type yet
        }
    }

    my $of := $descriptor.of;
    $v.throw( 'X::Parameter::Default::TypeCheck',
      :expected($var.WHAT), :got($default =:= Nil ?? 'Nil' !! $default) )
      unless nqp::istype($of, $default.WHAT) or $default =:= Nil or $of =:= Mu;
    $descriptor.set_default(nqp::decont($default));

    # make sure we start with the default if a scalar
    $var = $default if nqp::istype($what, Scalar);
}
multi sub trait_mod:<is>(Variable:D $v, :$dynamic!) {
    my $var  := $v.var;
    my $what := $var.VAR.WHAT;
    try { nqp::getattr(
            $var,
            $what.^mixin_base,
            '$!descriptor',
          ).set_dynamic($dynamic);
        CATCH {
            $v.throw( 'X::Comp::Trait::NotOnNative',
              :type<is>, :subtype<dynamic> ); # can't find out native type yet
        }
    }
}
multi sub trait_mod:<is>(Variable:D $v, :$export!) {
    if $v.scope ne 'our' {
        $v.throw('X::Comp::Trait::Scope',
          :type<is>,
          :subtype<export>,
          :declaring<variable>,
          :scope($v.scope),
          :supported(['our']),
        );
    }
    my $var  := $v.var;
    my @tags = 'ALL', (nqp::istype($export,Pair) ?? $export.key() !!
                       nqp::istype($export,Positional) ?? @($export)>>.key !!
                       'DEFAULT');
    EXPORT_SYMBOL($var.VAR.name, @tags, $var);
}

# "of" traits
multi sub trait_mod:<of>(Variable:D $v, |c ) {
    $v.throw('X::Comp::Trait::Unknown',
      :type<of>,
      :subtype(c.hash.keys[0]),
      :declaring(' variable'),
      :expected('TypeObject'),
    );
}
multi sub trait_mod:<of>(Variable:D $v, Mu:U $of ) {
    my $var  := $v.var;
    my $what := $var.VAR.WHAT;
    my $how  := $what.HOW;
    try { nqp::getattr(
            $var,
            $how.mixin_base($what),
            '$!descriptor'
          ).set_of(nqp::decont($of));
        CATCH {
            $v.throw( 'X::Comp::Trait::NotOnNative',
              :type<of>, :subtype($of.^name) ); # can't find out native type yet
        }
    }
    # probably can go if we have a COMPOSE phaser
    $how.set_name($what,"{$how.name($what)}[{$of.^name}]");
}

# phaser traits
multi sub trait_mod:<will>(Variable:D $v, $block, |c ) {
    $v.throw('X::Comp::Trait::Unknown',
      :type<will>,
      :subtype(c.hash.keys[0]),
      :declaring(' variable'),
      :expected('begin check final init end',
                'enter leave keep undo',
                'first next last pre post',
                'compose'),
    );
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$begin! ) {
    $block($v.var); # no need to delay execution
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$check! ) {
    $*W.add_phaser($v.slash, 'CHECK', $block);
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$final! ) {
    $v.throw('X::Comp::NYI', :feature("Variable trait 'will final {...}'"));
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$init! ) {
    $v.throw('X::Comp::NYI', :feature("Variable trait 'will init {...}'"));
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$end! ) {
    $*W.add_object($block);
    $*W.add_phaser($v.slash, 'END', $block);
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$enter! ) {
    $v.block.add_phaser('ENTER', $v.willdo($block, 1) );
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$leave! ) {
    $v.block.add_phaser('LEAVE', $v.willdo($block) );
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$keep! ) {
    $v.block.add_phaser('KEEP', $v.willdo($block));
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$undo! ) {
    $v.block.add_phaser('UNDO', $v.willdo($block));
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$first! ) {
    $v.block.add_phaser('FIRST', $v.willdo($block, 1));
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$next! ) {
    $v.block.add_phaser('NEXT', $block);
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$last! ) {
    $v.block.add_phaser('LAST', $block);
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$pre! ) {
    $v.block.add_phaser('PRE', $v.willdo($block, 1));
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$post! ) {
    $v.throw('X::Comp::NYI', :feature("Variable trait 'will post {...}'"));
}
multi sub trait_mod:<will>(Variable:D $v, $block, :$compose! ) {
    $v.throw('X::Comp::NYI', :feature("Variable trait 'will compose {...}'"));
}

# vim: ft=perl6 expandtab sw=4
