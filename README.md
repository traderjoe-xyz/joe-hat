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


### Use Virtualenv

