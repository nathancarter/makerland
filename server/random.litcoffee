
# Random Number Module

This module is for drawing random numbers from a variety of distributions.
It uses `Math.random()`, which is a uniform pseudo-random variable on the
interval [0,1], and leverages it to create a variety of other distributions.

## Uniform random variable on [a,b)

Draws a random number from the real interval [a,b) with uniform probability
density.  The number b will never be selected; the interval is open on that
end.

    module.exports.uniformOpen = ( a, b ) -> Math.random() * ( b - a ) + a

## Uniform random variable on {n,n+1,...,m-1,m}

Draws a random integer from the set of integers from n to m inclusive, with
each equally likely to be chosen.

    module.exports.uniformInteger = ( n, m ) ->
        ( Math.random() * ( m - n + 1 ) ) | 0 + n

## Uniform random variable on [a,b]

Same as `uniformOpen` except the number b can sometimes be selected.
However, as a tradeoff, only 100,000 distinct values (uniformly spaced) in
the interval [a,b] can be returned by this function.

    module.exports.uniformClosed = ( a, b ) ->
        module.exports.uniformInteger( a*100000, b*100000 ) / 100000

## Uniform random variable on A

Given an array A, draws a random element, with all equally likely to be
chosen.  If an entry appears more than once in A, it has a greater
likelihood of being chosen, because each of its occurrences is equally
likely to be chosen.

    module.exports.uniformFromArray = ( A ) ->
        A[module.exports.uniformInteger 0, A.length-1]
