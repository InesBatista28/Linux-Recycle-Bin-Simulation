

---







--

---



---

---

### Test Case 11: Empty Recycle Bin (Single Item)

**Objective:** Delete a specific item by ID

**Steps:**
1. Delete a file
2. Get its ID
3. Run: `./recycle_bin.sh empty <ID>`
4. Verify only that file removed

**Expected Result:**
- Selected file permanently deleted
- Metadata updated
- Other items unaffected

**Actual Result:**
- Item removed from files/
- Metadata entry removed
- Confirmation prompt respected if no --force

**Status:** ☑ Pass ☐ Fail

**Screenshots:** [If applicable]

---


