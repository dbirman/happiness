This is an overview file explaining what models exist in the Old Models folder. See forage_valuehappy_model for an overview of the most recent (and most successful) iteration. Feel free to contact me if you need to know more about a model, or if you'd like me to add additional comments to a model so that you can explore it in more detail.

1/20/2015, Dan Birman
danbirman@gmail.com

## Test Models

MVT_test_model - A test of the mean value theorem
rgb_model - A test of grass color growth
tutorial_model - Was going to be a tutorial for other people... scrapped it
link_model - A test to see how turtles would 'link' to form small local networks

## Early Models

forage_model - Original test model to get the basics of how things worked
forage2_model - Added pollen to give foragers more clues for movement.
forage3_model - I started using evolutionary algorithms to try to optimize the forager 'strategy' choices. Didn't work very well.

## Task Models

At some point I realized foragers needed to be able to track what they were 'doing' on any given tick. I eventually gave up on this thread but as you'll see many iterations of this model exist. Ultimately the problem is that it's more or less intractable to analyze what's happening in these models--they're just too complex. On the other hand, they work very well. Foragers do interesting things--its just impossible to characterize what they're doing.

The foragers do all sorts of cool things, like decide how much they 'trust' other foragers based on whether they've shared or mated with each other before, etc, etc...

forage_task_model - First version, works great!
forage_taskhe_model - Added hedonic/eudaimonic 
forage_THER_model - not sure...
forage_taskhe2_model - As the explanation shows I decided that agents needed to be stupid, i.e. not have access to environmental variables directly. This was conceptually simpler, but ends up with a similar result to the previous tasks--as the interface shows there are like 50 parameters! 

## Prop Model

At some point I realized that actually calculating every action of every forager was just too complex. So I decided to optimize by simulating actions. Each forager is 'simulated' doing a bunch of activities throughout a 'week', which is one tick of the simulation. The patches were very large and foragers could only move from one patch to the next very slowly (taking like... a week). This model is very efficient.

forage_prop_model (v5) - Thing started pretty simple (on the surface), although a lot of parameters are actually fixed in the background.
forage_100_model (v6) - Now I decided that hedonic/eudaimonic should be calculated on different time scales, so I combined v4 and v5 ('hourly' and 'weekly' respectively) to get my hedonic and eudaimonic calculations. Still: this is a very complex model with a lot of parameters that I didn't know what to do with. 
v7 - it appears I skipped v7.

## Bad models..

forage_taskv8_model - I decided to start experimenting with neural networks as a way of learning a forager 'strategy'. Great practice for me programming! Not so useful for actually simulating foragers. Warning: no comments and pretty complicated code! This was really more of an experiment.
forage_matrix_model - Realized my code was a mess so I added a mtarix package for netlogo which cleans things up a lot. 

## Back to task models!

I decided to go in favor of using 'memory' for foragers. Each forager has a 100 (hed) and 1000 (eud) length memory for previous 'ticks', where they store events that have happened. They use their memory to calculate a current approximation of their happiness and then use that to make decisions about what action to choose next.

This is actually pretty cool (as an idea), but in practice it's REALLY slow. Computationally intractable! 

forage_taskv9_model - non-functional
forage_taskv10_model - non-functional
forage_taskv10-norep-_model - functional, very slow. Foragers don't reproduce because otherwise the model slows down to a crawl.
forage_taskv10-nowan-_model - A very pretty model, nice to watch. There's no 'wandering' in this model so I had to implement some strategy for foragers to use each other as information about food sources. They do this by following scent trails left behind by the other foragers. It's pretty cool and very interesting to watch, but again there's ~15 parameters and it's impossible to really characterize what's happening.
v11/v12 - non-functional
v13 - I started settling on some ideas for experiments, but I was not convinced that the actual simulation was useful yet. This version is still fairly complex ( and slow! ).

## QL - Models

I tried implementing q-learning as a way to use reinforcement learning to learn survival strategies within the environment. Yes, it works eventually. No, it isn't useful. It takes far too long, netlogo isn't designed to do this kind of analysis, and ultimately it isn't convincing for our argument.

## Value Models

Finally I had an actual good idea. I needed a VERY simple model which might still show 'exploratory' behavior. I decided to go with two principles:

Movement should be based on an estimate of the environment's "value"
Everything else should be automatic (eating/drinking/socializing/reproducing)

It turns out this still does cool things and actually the foragers tend to 'cluster' in realistic ways around food and water sources. The code is relatively simple by comparison 

forage_Value_model - Original version, not very polished--but it runs! Just does lookup for the nearest neighbors, I was hoping to implement a kind of "scan" where the neighbors within a certain distance were all checked (discounted for distance) to determine the value of moving in that direction. I recommend looking at this file instead of at forage_value_model if there's any confusion about the comments. This model is very simple (although I didn't comment the code--sorry!).

## Current Model

I introduced hedonic/eudaimonic estimates to the forage_Value_model as well as optimizing the valuation algorithm. I think this is actually a useful direction to go in and hopefully it can be extended effectively!

see forage_valuehappy_model for an overview!