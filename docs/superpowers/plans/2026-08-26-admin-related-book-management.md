# Admin Catalog Related-Book Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a related-book management entry to every admin author, publisher, and category item that opens the existing book administration page with the correct pre-applied filter.

**Architecture:** Keep the existing admin book page as the only book-management surface. Extend the existing admin-books API with optional author, publisher, and category query parameters, then introduce a small, testable filter-context value object stored in the admin navigation state; the book page initializes its existing filter state from that context and renders a clear “currently managing” banner with a reset action.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, existing REST-backed admin repository.

**Spec:** User-approved conversational design from 2026-08-26.

## Global Constraints
- Reuse the existing admin book page; do not create a duplicate book-management screen.
- Provide entries from author, publisher, and category management lists.
- Preserve normal book edit, status and delete actions after navigation.
- Category filtering must preserve server-side parent-category expansion behavior.
- Add tests before production code changes and observe an expected failing test.

---

### Task 1: Extend and test the administrator book-query contract`r`n`r`n**Files:**`r`n- Create: `src/test/java/com/example/demo/controller/AdminBookControllerFilterTests.java``r`n- Modify: `src/main/java/com/example/demo/controller/AdminBookController.java``r`n- Modify: `src/main/java/com/example/demo/service/BookService.java``r`n`r`n- [ ] Write a failing controller test that expects `authorId`, `publisherId`, and `categoryId` to reach the service.`r`n- [ ] Run it and verify the expected compile/test failure.`r`n- [ ] Add optional filters to the administrator endpoint and query specification; reuse the existing direct-child category expansion.`r`n- [ ] Re-run the focused backend test until it passes.`r`n`r`n### Task 2: Map and test the related-book filter context

**Files:**
- Create: `test/admin_book_filter_context_test.dart`
- Create/Modify: exact production helper path determined after repository mapping

- [ ] Write a failing test describing each source type and reset behavior.
- [ ] Run the focused test and verify it fails because the helper does not exist.
- [ ] Implement the smallest immutable helper that represents a preselected filter and display label.
- [ ] Re-run the focused test until it passes.

### Task 3: Wire author, publisher and category actions into book management

**Files:**
- Modify: admin catalog/list page and route configuration discovered during mapping
- Test: focused helper tests plus existing model/page tests where applicable

- [ ] Add a “查看图书” action to author, publisher and category items.
- [ ] Pass the selected entity ID and human-readable name to the existing admin book page.
- [ ] Ensure a category action passes only the selected category ID so the backend maintains hierarchy expansion.

### Task 4: Initialize and explain filtered book management

**Files:**
- Modify: existing admin book page
- Modify/Create: filter-context helper and tests

- [ ] Initialize the existing book list filter from the passed context.
- [ ] Show the current management context and a reset-to-all-books action.
- [ ] Keep existing book actions available.

### Task 5: Verify and commit

- [ ] Format every changed Dart file.
- [ ] Run focused tests and relevant static analysis.
- [ ] Inspect Git diff and ensure only intended files are staged.
- [ ] Create a separate feature commit.

