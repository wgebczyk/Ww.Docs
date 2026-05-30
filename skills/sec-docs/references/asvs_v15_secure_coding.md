---
category-id: V15
category-title: "Secure Coding and Architecture"
asvs-version: "5.0"
requirement-count: 21
output-file: "asvs_v15_secure_coding.md"
---

# V15: Secure Coding and Architecture

## Requirements

### V15.1 — Secure Coding Documentation

#### V15.1.1 [L1/L2/L3]
Verify that application documentation defines risk based remediation time frames for 3rd party component versions with vulnerabilities and for updating libraries in general, to minimize the risk from these components.

#### V15.1.2 [L2/L3]
Verify that an inventory catalog, such as software bill of materials (SBOM), is maintained of all third-party libraries in use, including verifying that components come from pre-defined, trusted, and continually maintained repositories.

#### V15.1.3 [L2/L3]
Verify that the application documentation identifies functionality which is time-consuming or resource-demanding. This must include how to prevent a loss of availability due to overusing this functionality and how to avoid a situation where building a response takes longer than the consumer's timeout. Potential defenses may include asynchronous processing, using queues, and limiting parallel processes per user and per application.

#### V15.1.4 [L3]
Verify that application documentation highlights third-party libraries which are considered to be "risky components".

#### V15.1.5 [L3]
Verify that application documentation highlights parts of the application where "dangerous functionality" is being used.

### V15.2 — Dependency and Component Management

#### V15.2.1 [L1/L2/L3]
Verify that the application only contains components which have not breached the documented update and remediation time frames.

#### V15.2.2 [L2/L3]
Verify that the application has implemented defenses against loss of availability due to functionality which is time-consuming or resource-demanding, based on the documented security decisions and strategies for this.

#### V15.2.3 [L2/L3]
Verify that the production environment only includes functionality that is required for the application to function, and does not expose extraneous functionality such as test code, sample snippets, and development functionality.

#### V15.2.4 [L3]
Verify that third-party components and all of their transitive dependencies are included from the expected repository, whether internally owned or an external source, and that there is no risk of a dependency confusion attack.

#### V15.2.5 [L3]
Verify that the application implements additional protections around parts of the application which are documented as containing "dangerous functionality" or using third-party libraries considered to be "risky components". This could include techniques such as sandboxing, encapsulation, containerization or network level isolation.

### V15.3 — Safe Coding Practices

#### V15.3.1 [L1/L2/L3]
Verify that the application only returns the required subset of fields from a data object. For example, it should not return an entire data object, as some individual fields should not be accessible to users.

#### V15.3.2 [L2/L3]
Verify that where the application backend makes calls to external URLs, it is configured to not follow redirects unless it is intended functionality.

#### V15.3.3 [L2/L3]
Verify that the application has countermeasures to protect against mass assignment attacks by limiting allowed fields per controller and action, e.g., it is not possible to insert or update a field value when it was not intended to be part of that action.

#### V15.3.4 [L2/L3]
Verify that all proxying and middleware components transfer the user's original IP address correctly using trusted data fields that cannot be manipulated by the end user, and the application and web server use this correct value for logging and security decisions such as rate limiting.

#### V15.3.5 [L2/L3]
Verify that the application explicitly ensures that variables are of the correct type and performs strict equality and comparator operations. This is to avoid type juggling or type confusion vulnerabilities caused by the application code making an assumption about a variable type.

#### V15.3.6 [L2/L3]
Verify that JavaScript code is written in a way that prevents prototype pollution, for example, by using Set() or Map() instead of object literals.

#### V15.3.7 [L2/L3]
Verify that the application has defenses against HTTP parameter pollution attacks, particularly if the application framework makes no distinction about the source of request parameters (query string, body parameters, cookies, or header fields).

### V15.4 — Concurrency

#### V15.4.1 [L3]
Verify that shared objects in multi-threaded code (such as caches, files, or in-memory objects accessed by multiple threads) are accessed safely by using thread-safe types and synchronization mechanisms like locks or semaphores to avoid race conditions and data corruption.

#### V15.4.2 [L3]
Verify that checks on a resource's state, such as its existence or permissions, and the actions that depend on them are performed as a single atomic operation to prevent time-of-check to time-of-use (TOCTOU) race conditions.

#### V15.4.3 [L3]
Verify that locks are used consistently to avoid threads getting stuck, whether by waiting on each other or retrying endlessly, and that locking logic stays within the code responsible for managing the resource to ensure locks cannot be inadvertently or maliciously modified by external classes or code.

#### V15.4.4 [L3]
Verify that resource allocation policies prevent thread starvation by ensuring fair access to resources, such as by leveraging thread pools, allowing lower-priority threads to proceed within a reasonable timeframe.
