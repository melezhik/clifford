unit module Clifford;
use MultiVector;

role Vector does MultiVector does Positional is export {
    method blades { grep *.value, ((1, 2, 4 ... *) Z=> self[]) }
    method AT-KEY(UInt $n) { $n == 1 ?? self !! 0 }
    method norm { sqrt [+] self »**» 2 }
}

class MVector does MultiVector {
    has Real %.blades{UInt};
    multi method gist {
	my sub blade-gist($blade) {
	    join(
		'*',
		$blade.value,
		map { "e({$_ - 1})" },
		grep +*,
		($blade.key.base(2).comb.reverse Z* 1 .. *)
	    ).subst(/<|w>1\*/, '')
	}
	if    self.blades == 0 { return '0' }
	elsif self.blades == 1 {
	    given self.blades.pick {
		if .key == 0 {
		    return .value.gist;
		} else {
		    return blade-gist($_);
		}
	    }
	} else {
	    return 
	    join(
		' + ', do for sort *.key, self.blades {
		    .key == 0 ?? .value.gist !! blade-gist($_);
		}
	    ).subst('+ -','- ', :g);
	}
    }
    method AT-KEY(UInt $n) { self.new: :blades(grep { $n == [+] .key.polymod(2 xx *) }, self.blades) }
}

sub e(UInt:D $n) returns Vector is export { [flat 0 xx $n, 1] but Vector }

# Metric signature
our @signature = 1 xx *;

# utilities
my sub order(UInt:D $i is copy, UInt:D $j) {
    my $n = 0;
    repeat {
	$i +>= 1;
	$n += [+] ($i +& $j).polymod(2 xx *);
    } until $i == 0;
    return $n +& 1 ?? -1 !! 1;
}
my sub metric-product(UInt $i, UInt $j) {
    my $r = order($i, $j);
    my $t = $i +& $j;
    my $k = 0;
    while $t !== 0 {
	if $t +& 1 {
	    $r *= @Clifford::signature[$k];
	}
	$t +>= 1;
	$k++;
    }
    return $r;
}

# ADDITION
multi infix:<+>(Vector $a, Vector $b) returns Vector is export {
    return [($a[$_]//0) + ($b[$_]//0) for ^max($a.elems, $b.elems)] but Vector;
}
multi infix:<+>(MultiVector $A, MultiVector $B) returns MultiVector is export {
    my Real %blades{UInt} = $A.blades;
    for $B.blades {
	%blades{.key} :delete unless %blades{.key} += .value;
    }
    return MVector.new: :%blades;
}
multi infix:<+>(Real $s, MultiVector $A) returns MultiVector is export {
    my Real %blades{UInt} = $A.blades;
    %blades{0} :delete unless %blades{0} += $s;
    return MVector.new: :%blades;
}
multi infix:<+>(MultiVector $A, Real $s) returns MultiVector is export { $s + $A }

# GEOMETRIC PRODUCT
multi infix:<*>(MultiVector $A, MultiVector $B) returns MultiVector is export {
    my Real %blades{UInt};
    for $A.blades -> $a {
	for $B.blades -> $b {
	    my $c = $a.key +^ $b.key;
	    %blades{$c} :delete unless
	    %blades{$c} += $a.value * $b.value * metric-product($a.key, $b.key);
	}
    }
    return MVector.new: :%blades;
}

# EXPONENTIATION
multi infix:<**>(MultiVector $ , 0) returns MultiVector is export { return MultiVector.new }
multi infix:<**>(MultiVector $A, 1) returns MultiVector is export { return $A }
multi infix:<**>(MultiVector $A, 2) returns MultiVector is export { return $A * $A }
multi infix:<**>(MultiVector $A, UInt $n where $n %% 2) returns MultiVector is export {
    return ($A ** ($n div 2)) ** 2;
}
multi infix:<**>(MultiVector $A, UInt $n) returns MultiVector is export {
    return $A * ($A ** ($n div 2)) ** 2;
}

# SCALAR MULTIPLICATION
multi infix:<*>(MultiVector $,  0) is export { MultiVector.new }
multi infix:<*>(MultiVector $A, 1) is export { $A }
multi infix:<*>(MultiVector $A, Real $s) returns MultiVector is export { $s * $A }
multi infix:<*>(Real $s, Vector $V) returns Vector is export { [$s X* $V] but Vector }
multi infix:<*>(Real $s, MultiVector $A) returns MultiVector is export {
    return MVector.new: :blades(my Real %{UInt} = map { .key => $s * .value }, $A.blades);
}
multi infix:</>(MultiVector $A, Real $s) is export { (1/$s) * $A }

# SUBSTRACTION
multi prefix:<->(MultiVector $A) returns MultiVector is export { return -1 * $A }
multi infix:<->(MultiVector $A, MultiVector $B) returns MultiVector is export { $A + -$B }
multi infix:<->(MultiVector $A, Real $s) returns MultiVector is export { $A + -$s }
multi infix:<->(Real $s, MultiVector $A) returns MultiVector is export { $s + -$A }

# COMPARISON
multi infix:<==>(MultiVector $A, MultiVector $B) returns Bool is export { $A - $B == 0 }
multi infix:<==>(Real $x, MultiVector $A) returns Bool is export { $A == $x }
multi infix:<==>(MultiVector $A, Real $x) returns Bool is export {
    my $narrowed = $A.narrow;
    $narrowed ~~ Real and $narrowed == $x;
}

# GRADE PROJECTION

