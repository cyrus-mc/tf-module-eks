# Contributing
---
Contributions encouraged. Please first create or associate a JIRA item/task for the change you'll be making, and
document the need for the bugfix/feature/enhancement/securityfix/etc.

## Branches
---
* Create a new branch for new work
    * Name branch after your JIRA
* Avoid using long-lived branches (i.e. using feature branch for production)

## Pull Requests
---
* Update CHANGELOG.md with your changes
    * Title changes appropriately (fixed/enhancement/security/etc)
* Update README.md as appropriate
* Ensure all tests are passing and open a PR seeking at least one, if not more, approvals
* Once all tests are passing, with no less than at least one approval:
    * merge back to the Main Branch when finished
* After merging, tag the merge commit in the Main Branch with an incremented version number from the prior tag
  (e.g. 7.0.0)
