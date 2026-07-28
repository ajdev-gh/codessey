---
title: "Zero to O(N) #02: Palindrome Number & Half-Reversal Tricks"
date: 2026-07-28T17:49:00+05:30
draft: false
tags: ["DSA", "leetcode", "Zero to O(n)", "java"]
series: ["Zero to O(N)"]
math: true
---

Welcome to issue #02 of **Zero to $O(N)$**. Today we are tackling 
**LeetCode 9: Palindrome Number**, where we must determine whether an integer 
reads the exact same forward and backward without converting it to a string.

It looks simple on the surface, but solving it in optimal space forces us to 
think carefully about integer overflow, modulo arithmetic, and loop termination.

---

## The Problem

> Given an integer `x`, return `true` if `x` is a **palindrome**, and `false` 
> otherwise.

### Examples
* **Input:** `x = 121` $\rightarrow$ **Output:** `true`
* **Input:** `x = -121` $\rightarrow$ **Output:** `false` (Reads `-121` left-to-right, but `121-` right-to-left)
* **Input:** `x = 10` $\rightarrow$ **Output:** `false` (Reads `01` backward)

---

## The Intuition: Edge Cases & String Conversion Traps

The naive solution is converting the integer to a string or character array, 
reversing it, and checking equality:

```java
public class Solution {
    public boolean isPalindromeString(int x) {
        String str = Integer.toString(x);
        String reversed = new StringBuilder(str).reverse().toString();
        return str.equals(reversed);
    }
}
```

### Why String Conversion Is Flawed
1. **Space Complexity:** Allocates a $O(N)$ string buffer where $N$ is the number 
   of digits.
2. **Interview Follow-Up:** Interviewers explicitly ban string conversion to test 
   your raw mathematical problem-solving skills.

---

## Mathematical Edge Cases

Before writing math logic, identify impossible cases immediately:
1. **Negative numbers:** `-121` becomes `121-` due to the leading minus sign. 
   All negative numbers are invalid.
2. **Trailing zeros:** Numbers ending in `0` (except `0` itself) cannot be 
   palindromes because integers cannot have leading zeros (e.g., `10` reversed 
   is `01`, which is impossible).

---

## The Optimization: Half-Number Reversal

Instead of reversing the entire integer—which risks **integer overflow** if the 
reversed number exceeds `Integer.MAX_VALUE`—we only need to reverse **half** 
the number.

If `1221` is a palindrome, reversing the back half (`21` $\rightarrow$ `12`) will match 
the front half (`12`).

```java
public class Solution {
    public boolean isPalindrome(int x) {
        // Edge cases: Negative numbers and non-zero numbers ending in 0
        if (x < 0 || (x % 10 == 0 && x != 0)) {
            return false;
        }

        int reversedHalf = 0;
        
        // Process digits until we reach or cross the midpoint
        while (x > reversedHalf) {
            int lastDigit = x % 10;
            reversedHalf = (reversedHalf * 10) + lastDigit;
            x /= 10;
        }

        // Even length: x == reversedHalf (e.g., 1221 -> x = 12, reversedHalf = 12)
        // Odd length:  x == reversedHalf / 10 (e.g., 12321 -> x = 12, reversedHalf = 123)
        return x == reversedHalf || x == reversedHalf / 10;
    }
}
```

---

## Dry Run Execution

Let us trace `x = 12321` (odd-length palindrome):

| Loop Step | `x` | `x % 10` (Digit) | `reversedHalf` | Loop Condition (`x > reversedHalf`) |
|---|---|---|---|---|
| **Start** | `12321` | — | `0` | `12321 > 0` (True) |
| **Pass 1** | `1232` | `1` | `1` | `1232 > 1` (True) |
| **Pass 2** | `123` | `2` | `12` | `123 > 12` (True) |
| **Pass 3** | `12` | `3` | `123` | `12 > 123` (False - Loop Ends) |

* **Final Check:** `x` is `12`. `reversedHalf / 10` is `123 / 10` = `12`.
* `12 == 12` evaluates to **`true`**.

---

## Complexity Analysis

* **Time Complexity:** $O(\log_{10}(N))$ — In each iteration, we divide the input 
  number by 10. The number of digits in `N` is $\lfloor \log_{10}(N) \rfloor + 1$. 
  Since we only process half the digits, execution takes at most $\approx \frac{\log_{10}(N)}{2}$ 
  steps.
* **Space Complexity:** $O(1)$ — We use only two scalar variables (`x` and 
  `reversedHalf`), requiring constant space overhead.

---

## Key Takeaway
You do not need to process an entire input to prove symmetry. By stopping at 
the midpoint, we avoid string heap allocations and integer overflow in one go.

See you next week for issue #03!
