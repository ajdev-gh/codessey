---
title: "Zero to O(n) #3: LeetCode 13 - Roman to Integer in Java"
date: 2026-08-04T21:30:00+05:30
draft: false
tags: ["leetcode", "java", "algorithms", "dsa", "zero-to-on"]
series: ["Zero to O(n)"]
math: false
---

Welcome to **Zero to O(n) #3**. In this entry, we tackle **LeetCode 13: Roman to Integer**.

While Roman numerals look straight forward at first glance, the subtraction rules (like `IV` for 4 or `IX` for 9) introduce a small twist. We will look at how to process strings from right to left to solve this in a single pass with optimal $O(n)$ time complexity and $O(1)$ auxiliary space.

---

## Problem Statement

Given a Roman numeral string `s`, convert it to an integer.

Roman numerals are represented by seven different symbols:

| Symbol | Value |
| :--- | :--- |
| **I** | 1 |
| **V** | 5 |
| **X** | 10 |
| **L** | 50 |
| **C** | 100 |
| **D** | 500 |
| **M** | 1000 |

### Rules & Subtraction Exceptions

Generally, Roman numerals are written largest to smallest from left to right:
* `VI` = $5 + 1 = 6$
* `MDCLXVI` = $1000 + 500 + 100 + 50 + 10 + 5 + 1 = 1666$

However, when a smaller value appears **before** a larger value, subtraction applies:
* **I** placed before **V** (5) or **X** (10) makes 4 or 9.
* **X** placed before **L** (50) or **C** (100) makes 40 or 90.
* **C** placed before **D** (500) or **M** (1000) makes 400 or 900.

---

## Strategy: Right-to-Left Traversal

Instead of looking ahead or managing complex two-character string slices, we can traverse the string from **right to left**.

### The Core Insight
* Keep track of the value of the **previous (rightmost)** character we just processed.
* If the current character's value is **less than** the previous character's value, we subtract it from the total running sum (e.g., encountering `I` after seeing `V` means `5 - 1 = 4`).
* Otherwise, we **add** it to the total running sum.

---

## Java Implementation

\`\`\`java
class Solution {
    public int romanToInt(String s) {
        int total = 0;
        int prevValue = 0;

        for (int i = s.length() - 1; i >= 0; i--) {
            int currentValue = getValue(s.charAt(i));

            if (currentValue < prevValue) {
                total -= currentValue;
            } else {
                total += currentValue;
            }

            prevValue = currentValue;
        }

        return total;
    }

    private int getValue(char c) {
        switch (c) {
            case 'I': return 1;
            case 'V': return 5;
            case 'X': return 10;
            case 'L': return 50;
            case 'C': return 100;
            case 'D': return 500;
            case 'M': return 1000;
            default: return 0;
        }
    }
}
\`\`\`

---

## Step-by-Step Execution Trace

Let us trace `s = "MCMXCIV"` (1994):

| Iteration | Char | `currentValue` | Comparison (`curr < prev`) | Action | `total` | `prevValue` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `'V'` | 5 | $5 < 0$ (False) | `+ 5` | 5 | 5 |
| 2 | `'I'` | 1 | $1 < 5$ (True) | `- 1` | 4 | 1 |
| 3 | `'C'` | 100 | $100 < 1$ (False) | `+ 100` | 104 | 100 |
| 4 | `'X'` | 10 | $10 < 100$ (True) | `- 10` | 94 | 10 |
| 5 | `'M'` | 1000 | $1000 < 10$ (False) | `+ 1000` | 1094 | 1000 |
| 6 | `'C'` | 100 | $100 < 1000$ (True) | `- 100` | 994 | 100 |
| 7 | `'M'` | 1000 | $1000 < 100$ (False) | `+ 1000` | 1994 | 1000 |

**Final Result**: `1994`

---

## Complexity Analysis

* **Time Complexity**: $O(n)$, where $n$ is the length of string `s`. We iterate through the string exactly once.
* **Space Complexity**: $O(1)$ auxiliary space. Helper methods use switch-case jumps without creating extra hash maps or data structures.
