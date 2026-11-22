# objective

Here is a series of things that need inproving:

- when player is shooting the speed is reduced compared to normal movement.
- the bullet animation should not be a traveling little beam of light, should be more realistic beam that has a visible trajectory and impact effect.
- make the collision box of zombies being hit by bullets more generous, right now you need to hit them very precisely for the bullets to register.
- increase performance by spawning zombies only close to the player, and de-spawning zombies that are far away from camera.
- Game is too easy: it is easy for player to run around zombies. we need more zombies.
- over time, the game should gradually become more difficult by increasing the number of zombies and their speed.
- Over time start spawning boss zombies to increase difficulty. Boss zombies should have more health than regular zombies. it should be clear they are boss zombies by their size being 20% larger than regular zombies.
- the floor of the game has no texture. Add street texture to make it look more realistic. 
- when traveling to the end of the map you can see that it is just the end of the game. add fences to block the player from going further. and make the maps extend over the fences enough so that the player cannot see the real end of the map.
- improve performance by whatever is needed in modern games, where I believe the computations focus only on what is close to the player (e.g., culling distant objects, level of detail adjustments, and efficient memory management, what is far away can be ignored or simplified). I don't know details on this, explore.
- add vfx for main interactions: blood splatter on hit and death, explosion, fires of barrels
- add more realistic sound effects for main interactions: gunshots, zombie groans, explosions, and environmental sounds like footsteps and ambient city noise. right now the synthesizer sounds artificial and do not match the intensity of the game.
- if things can be done in parallel start ultracode with separate git worktrees
- 