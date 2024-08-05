// block with an empty expression, however, the compiler will
// insert an empty expression automatically: `let none = { () }`
// let none = {};

// block with let statements and an expression.
let sum = {
    let a = 1;
    let b = 2;
    a + b // last expression is the value of the block
};

// block is an expression, so it can be used in an expression and
// doesn't have to be assigned to a variable.
{
    let a = 1;
    let b = 2;
    a + b; // not returned - semicolon.
    // compiler automatically inserts an empty expression `()`
};
