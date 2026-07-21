---
date: '2026-07-21T22:04:19+05:30'
draft: false
title: 'Zero to O(N) #01: Two Sum'
tags: ['Zero-To-O(N)']
math: true
ShowToc: true
---

Welcome to the first entry of **Zero to $O(N)$**. We are kicking things
off with **LeetCode 1: Two Sum**, a fundamental challenge where we must 
find two numbers in an array that sum to a given target and return their 
indices.

It is the quintessential interview question for a reason. It perfectly
demonstrates how trading memory for speed can instantly drop an
algorithm's execution time.

## The Problem

Given an array of integers `nums` and an integer `target`, return
indices of the two numbers such that they add up to `target`.

You may assume that each input would have **exactly one solution**, and
you may not use the same element twice.

### Example
Input: nums = [2, 7, 11, 15], target = 9
Output: [0, 1] (Because nums[0] + nums[1] == 9)

---

## The Intuition: Spotting the Trap

The most instinctive way to solve this is to act like a human
brute-forcing a puzzle. You pick the first number, then scan through
every single other number to see if they hit the target. If they do not,
you move to the second number and repeat.

### The Brute Force Approach
In Java, this translates to nested loops checking every possible pair:

```java
public class Solution {
    public int[] twoSumBruteForce(int[] nums, int target) {
        int n = nums.length;
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                if (nums[i] + nums[j] == target) {
                    return new int[] { i, j };
                }
            }
        }
        return new int[] {};
    }
}
```

### Why This Fails the Scale Test
This works fine for small arrays. But if `nums` has 10,000 elements, your
program performs roughly $10,000 \times 10,000$ operations.

* **Time Complexity:** $O(N^2)$ - The nested loop causes a quadratic time
  explosion.
* **Space Complexity:** $O(1)$ - We are not storing extra data, so memory
  usage is constant.

---

## The Optimization: Flipping the Perspective

To get from $O(N^2)$ down to $O(N)$, we need to stop looking backward.
Instead of asking, *"Which two numbers add up to target?"*, look at the
current number ($x$) and ask:

> *"Have I already seen the exact number needed to complete this pair?"*

The needed number is simple math: $\text{complement} = \text{target} - x$.

If we store every number we visit along with its index inside a
**HashMap**, we can look up the complement instantly in $O(1)$ average
time.

---

## The $O(N)$ Solution

Here is the optimized approach. We iterate through the array exactly once:

```java
import java.util.HashMap;
import java.util.Map;

public class Solution {
    public int[] twoSum(int[] nums, int target) {
        Map<Integer, Integer> seen = new HashMap<>();
        
        for (int currentIndex = 0; currentIndex < nums.length; currentIndex++) {
            int currentNum = nums[currentIndex];
            int complement = target - currentNum;
            
            if (seen.containsKey(complement)) {
                return new int[] { seen.get(complement), currentIndex };
            }
            
            seen.put(currentNum, currentIndex);
        }
        
        return new int[] {};
    }
}
```

### Dry Run Execution
Let us trace `nums = [2, 11, 7]`, `target = 9`:
1. **Index 0 (num = 2):** $\text{complement} = 9 - 2 = 7$. Is 7 in `seen`?
   No. Add `(2, 0)` to `seen`.
2. **Index 1 (num = 11):** $\text{complement} = 9 - 11 = -2$. Is -2 in
   `seen`? No. Add `(11, 1)` to `seen`.
3. **Index 2 (num = 7):** $\text{complement} = 9 - 7 = 2$. Is 2 in
   `seen`? **Yes!** It is at index 0. Return `[0, 2]`.

---

## Complexity Analysis

By introducing a hash map, the performance profile changes completely:

* **Time Complexity:** $O(N)$ - We loop through the array of length $N$
  exactly once. HashMap operations (`containsKey` and `put`) take $O(1)$
  time on average.
* **Space Complexity:** $O(N)$ - In the worst-case scenario, we might store
  almost every element in the map before finding a match.

## The Takeaway
We traded space for speed. By allocating a small amount of memory to
remember the past, we turned a slow, dragging algorithm into a highly
efficient, single-pass machine.

See you next Tuesday for issue #02!
