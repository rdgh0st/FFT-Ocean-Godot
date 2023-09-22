# gd-complex

A simple plugin providing complex number algebra for GDScript. Loads a Singleton class that provides the Complex class for use within the game.

### Example usage

Create a complex number with `.new(real, imaginary)`:

```
var c = Complex.new(0.0, 1.0)
print(c.repr())
```

will print `0+1i`. The following members and operators are available on the complex class:

* `.real`: real part
* `.imag`: imaginary part
* `.sum(x)`: add another number (Complex or not)
* `.sub(x)`: subtract another number (Complex or not)
* `.mul(x)`: multiply by another number (Complex or not)
* `.div(x)`: divide by another number (Complex or not)
* `.pow(x)`: elevate to the power of another number (Complex or not)
* `.exp()`: exponentiate
* `.log()`: natural logarithm
* `.sqrt()`: square root
* `.sin()`: sine
* `.cos()`: cosine
* `.conj()`: conjugate
* `.mod()`: modulus
* `.mod2()`: modulus squared
* `.phase()`: phase
* `.repr()`: string representation
