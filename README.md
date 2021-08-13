# [JoeHatContract](https://github.com/LouisMeMyself/JoeHatContract)

The Joe Hat Contract is an Avalanche smart contract for trading $HAT, 
it dictates its price, and you can trade $HAT directly with this contract.

It uses the JoeHat, which is an ERC-20 token.

Why did we decide to build a brand-new contract
-------

As the idea behind joeHat comes from unisocks, we could have seeded a pool with $HAT
and Avax.

That would have cost us a lot of money, because we chose to gave 80% of the supply
because the current price of the token is around 15 Avax per Hat. Last issue is that
we want to pay for the hat and for the delivery and with uniswap pool, the price is
dictated by the Avax reserve in the pool. 

I discovered that it can be improved for $HAT because when someone redeems a real 
hat, the token gets burned. So we could remove some Avax in the contract without 
rug-pulling anyone. To incentive people to HODL their token or redeem a real hat, we 
have added a percentage reduction in earnings when selling. Those parts can be 
withdrew to cover part of the costs of the real hats.

How it works
-------

The contract follow the xy=k curve that I expained on 
[twitter](https://twitter.com/traderjoe_volly/status/1418281845498675201).

When you buy a $HAT, it calculates the amount you need in Avax.

When you sell $HAT for avax, it calculates the price, reduced approximately by a/b.

For the last hat, the price will be 2*k, which is 4 times the previous one.


How it really works
-------

### For Hat from 149 to 1:

The first 149 hats will be priced following the uniswap curve, thus xy=k.
We chose the hats to be priced at 15 avax per hats for the 30rd, that means 

```
k = reserveAvax * reserveHats = (30 * 15) * 30 = 13 500.
```

That means, that if you're buying the 56th hats, the price in avax would be :

```
price = k / 56 - k / 57 = 4.23 avax
```

When you're swapping Hats for Avax, i.e., selling it, the price will be
approximately lowered by a/b%, in our case, 5%.

Let's say you're swapping 5 hats for avax, and that there are 50 hats left in the 
contract, it will be calculated like so :

```
price with fees = k / 50 - k / (50 + 5 * 0.95) = 18.85 Avax
```

If you're swapping hats for avax, but you want to receive 20 avax, you'll need :
First as there are 50 hats, that means that the contract has 270 Avax (k/50).

```
hats with fees = k / 270 - k / (270 - 20 * 1.05) = 4.22 $HAT
```

### For the last Hat (i.e., 1 to 0)

We really wanted the 150 caps to be purchasable, and uniswap curve doesn't allow that 
because as xy = k, x = k/y, if y goes to 0, then the price is... infinity.

We chose to price the last $Hat 4 times the last one. To use a new function for this 
matter. We have chosen a straight line to make it as simple as possible because it's 
already hard to use 2 functions instead of only one to price an asset. 

As there is only one hat using that function, it's kind of easy to calculate the price:

```
price = amount_bought * last_hat_price = amount_bought * k * 2.
```

### The hardest part

Everything looks fine, but what happens if you buy an amount of $HAT that crosses both 
function. Let's say 3 $HAT and there is only 3 left in the contract, we calculate the 
price like so :

```
oldHat = 3 - 1 = 2
newHat = 3 - 2 = 1
```

With those numbers, we just calculate the price with the first function, or the second one. 
If you want to sell tokens, it will be calculated with a new amount equals to

```
newAmount = amount / 0.95
or 
newAmount = amount * 0.95
```

It depends on if you're swapping an exact amount of $HAT for Avax, or $HAT for an exact 
amount of Avax.