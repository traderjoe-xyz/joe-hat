# [Joe Hat](https://github.com/traderjoe-xyz/joe-hat)

The Joe Hat Bonding Curve Contract is an Avalanche smart contract for trading HAT.
~~it dictates its price, and you can trade $HAT directly with this contract.~~

It uses the JoeHat, which is an ERC-20 token.

Why did we decide to build a brand-new contract
-------

The inspiration of JoeHat comes from Unisocks, which uses a regular Uniswap
v2 SOCKS/ETH pool seeded with 500 SOCKS.

Because we gave away 100 of 150 HATs, we had to change our approach to ensure a
few things:

- Buying a HAT fron the bonding curve increases the price of the next HAT.
- We could account for the (unlikely) event that all 100 HATs were dumped.
- We could seed the bonding curve in an affordable way that without having the
  user to pay for the actual cost and shipment of the physical hat.

~~As the idea behind joeHat comes from unisocks, we could have seeded a pool with $HAT
and Avax.

That would have cost us a lot of money, because we chose to gave 80% of the supply
because the current price of the token is around 15 Avax per Hat. Last issue is that
we want to pay for the hat and for the delivery and with uniswap pool, the price is
dictated by the Avax reserve in the pool.~~

The general idea of this custom bonding curve contract is that it takes a small
percentage of each sale that is used by the team to fund the cost and shipping
of the hat.

// Not sure what this means 
I discovered that it can be improved for $HAT because when someone redeems a real 
hat, the token gets burned. So we could remove some Avax in the contract without 
rug-pulling anyone. To incentive people to HODL their token or redeem a real hat, we 
have added a percentage reduction in earnings when selling. Those parts can be 
withdrew to cover part of the costs of the real hats.

How it works
-------

The contract follow the xy=k curve that I expained on 
[twitter](https://twitter.com/traderjoe_volly/status/1418281845498675201).

When you buy a HAT, it calculates the amount you need in Avax.

// What is a and b? Try to avoid using random variables
When you sell HAT for avax, it calculates the price, reduced approximately by a/b.

// Why is it 2k?
For the last hat, the price will be 2*k, which is 4 times the previous one.


How it really works
-------

### For Hat from 1 to 149:

The first 149 hats will be priced following the Uniswap v2 curve, xy=k.
We chose the hats to be priced at 15 avax per hats for the 30th, that means 

```
k = reserveAvax * reserveHats = (30 * 15) * 30 = 13 500.
```

That means, that if you're buying the 56th HAT, the price in avax would be :

```
price = k / 56 - k / 57 = 4.23 avax
```

When you're swapping HATs for AVAX, i.e., selling it, the price will be
approximately lowered by a/b%, in our case, 5%.

Let's say you're swapping 5 HATs for AVAX, and that there are 50 hats left in the 
contract, it will be calculated like so :

// This is the price for each of the 5 HATs? Or price for all 5 HATs?
```
price with fees = k / 50 - k / (50 + 5 * 0.95) = 18.85 Avax
```

Now let's say you want to sell some HATs for exactly 20 AVAX. And let's assume
there's already 50 HATs in the bonding curve contract. First, that means there's `k/50 =
270` AVAX in the contract.

~~If you're swapping HATs for avax, but you want to receive 20 avax, you'll need :
First as there are 50 hats, that means that the contract has 270 Avax (k/50).~~
Then to calculate how many HATs you'll get:
```
hats with fees = k / 270 - k / (270 - 20 * 1.05) = 4.22 HATs
```

### For the last Hat (i.e., 1 to 0)

We really wanted the 150 caps to be purchasable, and Uniswap v2 curve doesn't allow that 
because as `xy = k` and `x = k/y`, then if y goes to 0, then the price goess to... infinity.

We chose to price the last HAT 4 times the last one. ~~To use a new function for this 
matter.~~ We have chosen a straight line function for the last HAT to make it as simple as possible because it's 
already hard to use 2 functions instead of only one to price an asset. 

As there is only one HAT using this function, it's trivial to calculate the price:

// Can you elaborate on this equation a bit more? What does amount_bought mean?
```
price = amount_bought * last_hat_price = amount_bought * k * 2.
```

### The hardest part

// This part needs more explanation. Don't really get the logic here.
Everything looks fine, but what happens if you buy an amount of $HAT that crosses both 
function. Let's say 3 $HAT and there is only 3 left in the contract, we calculate the 
price like so:

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
