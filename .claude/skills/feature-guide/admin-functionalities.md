## Feature: Admin functionalities

### What It Does

A user logging in with `ROLE_ADMIN` (seeded credentials `admin@portal.com` / `admin123`) gets a private `/admin` area with three tools: **Company Management** (CRUD over the company catalogue), **Employer Management** (search a user by email, promote a job seeker to employer, assign/reassign a company to an employer), and **Contact Messages** (paginated, sortable inbox of contact-form submissions with a "close" action). A dashboard at `/admin` links to all three and shows a live company count.

### User Flow

1. Login at `/login` → `AuthContext.login` (`src/context/AuthContext.jsx:163`) finds the admin in `DUMMY_USERS.admins` (line 102-110), writes `authToken` + `jobPortalUser`, and exposes `isAdmin` (line 331).
2. `Navbar` renders the admin section of the avatar dropdown only when `isAdmin` — `src/components/Navbar.jsx:307-368` (links to `/admin/companies`, `/admin/employers`, `/admin/contact-messages`). Note: there is **no navbar link to the `/admin` dashboard itself**; it is reachable only by typing the URL.
3. Every admin route is wrapped in `<ProtectedRoute allowedRoles={['ROLE_ADMIN']}>` in `src/App.jsx:99-130`. `ProtectedRoute` (`src/components/ProtectedRoute.jsx:16-23`) redirects anonymous users to `/login` and wrong-role users to `/`.
4. **Company Management**: table of `companies` from `CompaniesContext`. "Add New Company" / "Edit" open an inline `<form>` inside the table row; submit runs `handleSubmit` (`CompanyManagement.jsx:32`), which writes to `localStorage.companiesOverrides` and calls `refetch()`. "Delete" opens a modal → `confirmDelete` (line 113) pushes the id into `localStorage.deletedCompanyIds`.
5. **Employer Management**: `handleSearchUser` (`EmployerManagement.jsx:66`) merges a hardcoded `dummyUsers` array (lines 87-93) with `localStorage.registeredUsers` and matches on email. If the found user is `ROLE_JOB_SEEKER`, an "Elevate to Employer" button calls `handleElevateToEmployer` (line 125), rewriting that user's `role` in `registeredUsers`. If `ROLE_EMPLOYER`, a company `<select>` + `handleAssignCompany` (line 23) writes `companyId`/`companyName`/`company` back onto the user record. `ROLE_ADMIN` users are blocked (line 287).
6. **Contact Messages**: `useEffect` on `[sortBy, sortDir, pageNumber, pageSize]` (`ContactMessages.jsx:26`) calls `fetchOpenContactMsgsWithPaginationAndSort`. Row click expands the full message; "Close" opens a confirm modal → `updateContactStatus(id, 'CLOSED')` then re-fetch (which drops the row, since only `status === 'OPEN'` is returned).

### Key Files

| File | Role |
| --- | --- |
| `src/App.jsx` (lines 98-130) | Admin route registration + role guard |
| `src/components/ProtectedRoute.jsx` | Role enforcement |
| `src/components/Navbar.jsx` (307-368) | Admin dropdown links |
| `src/pages/admin/Dashboard.jsx` | Landing page, card grid, company count |
| `src/pages/admin/CompanyManagement.jsx` | Company CRUD UI + localStorage writes |
| `src/pages/admin/EmployerManagement.jsx` | User search, role elevation, company assignment |
| `src/pages/admin/ContactMessages.jsx` | Paginated message inbox |
| `src/context/AuthContext.jsx` | Admin seed user, `isAdmin` flag |
| `src/contexts/CompaniesContext.jsx` | `companies`, `loading`, `refetch` (5-min TTL cache) |
| `src/services/companyService.js` | `fetchCompanies` (reads `mockData.js`) |
| `src/services/contactService.js` | All contact-message reads/writes |
| `src/data/mockData.js` | `companiesData`, `jobs` source |

### Data Flow Diagram

```
Contact Messages (correct, service-backed):
  Admin action → ContactMessages.jsx → contactService.fetchOpenContactMsgs…()
                                     → localStorage['contactMessages']
        ↑                                          |
        └────── setMessages / fetchMessages ←──────┘

Company Management (broken loop — no service layer):
  Admin submit → CompanyManagement.handleSubmit → localStorage['companiesOverrides']
                                                   (nothing reads this key)
                        ↓ refetch()
              CompaniesContext.loadCompanies → companyService.fetchCompanies
                                                → mockData.companiesData  ✗ overrides ignored

Employer Management (page writes localStorage directly, no service):
  Search/Assign → EmployerManagement handlers → localStorage['registeredUsers'] → local component state
```

### State & Storage

**Context state consumed by admin pages**

- `CompaniesContext`: `companies: Company[]`, `loading: boolean`, `refetch(force?)`, `forceRefresh()` — 5-minute TTL, auto-refresh on interval and window focus (`CompaniesContext.jsx:62-80`).
- `AuthContext`: `user` (`{ userId, name, email, mobileNumber, role, company, profileComplete }`), `isAdmin`, `isLoading`.
- `ThemeContext`: `theme` — destructured in all four admin pages but never actually used (dark mode is done with Tailwind `dark:` classes); it is dead code.

**Local component state**: `CompanyManagement` — `formData` (10 string fields), `editingCompanyId`, `isAddingNew`, `deleteConfirmation`, `isSaving`. `EmployerManagement` — `searchEmail`, `searchedUser`, `selectedCompanyId`. `ContactMessages` — `messages`, `sortBy`/`sortDir`, `pageNumber`/`pageSize`/`totalPages`/`totalElements`, `expandedMessageId`.

**localStorage keys**

| Key | Written by | Shape |
| --- | --- | --- |
| `contactMessages` | `contactService` | `[{ id, name, email, userType, subject, message, status: 'OPEN'\|'CLOSED', createdAt }]` |
| `registeredUsers` | `AuthContext.register`, `EmployerManagement` | `[{ id, name, email, mobileNumber, password, role, companyId?, companyName?, company? }]` |
| `companiesOverrides` | `CompanyManagement` only | `{ [companyId]: {…companyFields} }` — **never read** |
| `deletedCompanyIds` | `CompanyManagement` only | `number[]` — **never read** |
| `jobPortalUser` / `authToken` | `AuthContext` | logged-in user object / mock JWT string |

### Bugs and Gaps Worth Knowing

1. **Company CRUD does not persist visibly.** `CompanyManagement.handleSubmit` (line 49-60) and `confirmDelete` (line 119-121) write `companiesOverrides` / `deletedCompanyIds`, but `fetchCompanies` in `src/services/companyService.js:7-13` returns raw `companiesData` from `mockData.js` and never merges or filters those keys. The success toast fires, `refetch()` runs, and the table is unchanged. This is the single biggest thing to fix.
2. **`refetch()` after a save is usually a no-op anyway.** `loadCompanies` short-circuits when the 5-minute cache is still valid (`CompaniesContext.jsx:35-38`) because `refetch` is exposed as `loadCompanies` (default `force = false`). Admin pages should call `forceRefresh()` instead.
3. **Rules violation — admin pages bypass the service layer.** `.claude/rules/data-layer.md` says page components must not touch data directly, yet `CompanyManagement` and `EmployerManagement` both call `localStorage` inline. There is no `adminService.js` / `userService.js`.
4. **Locations round-trips inconsistently.** On create, `locations` is split into an array (`CompanyManagement.jsx:56`); on edit it is stored as the raw comma string (line 52), and `handleEdit` puts the array straight into a text input (line 86).
5. **Elevation is not reflected in the active session.** If the elevated user is currently logged in, their `jobPortalUser` in localStorage keeps the old role until re-login.
6. **Duplicated user directory.** `EmployerManagement.jsx:87-93` re-declares the dummy users (without passwords) instead of importing from `AuthContext`'s `DUMMY_USERS`, so the two lists can drift. Elevating a dummy user silently does nothing persistent (line 51 shows a "(demo user)" success message).
7. **React key warning** in `CompanyManagement.jsx:389` — the `<>` fragment wrapping each row pair has no `key`; the key is on the inner `<tr>`.

### How to Extend

- **Make company CRUD real**: add `updateCompany`/`createCompany`/`deleteCompany` to `src/services/companyService.js`, and change `fetchCompanies` to merge `companiesOverrides` over `companiesData` and filter out `deletedCompanyIds` before mapping jobs. Then have `CompanyManagement` call those services (with `await delay()` inside the service, per the data-layer rules) and use `forceRefresh()`.
- **Add a new company field**: add it to `companiesData` in `src/data/mockData.js`, to the `formData` initial object + `resetForm` in `CompanyManagement.jsx` (lines 10-21 and 138-152), to `handleEdit` (line 80), to both form JSX blocks (add-new around line 229, edit around line 461), and to the table header/cell if it should be listed.
- **Add a new admin page**: create it in `src/pages/admin/`, register the route in `App.jsx` wrapped in `<ProtectedRoute allowedRoles={['ROLE_ADMIN']}>`, add a `Link` in the `isAdmin` block of `Navbar.jsx`, and push a card object into `adminCards` in `Dashboard.jsx:9`.
- **Connect to a real API**: services are the only seam you need — replace the `localStorage` bodies in `contactService.js` and `companyService.js` with `fetch` calls. The contact service's pagination return shape (`{ content, totalElements, totalPages, number, size }`) is already Spring Data `Page`-shaped, so a Spring backend drops in unchanged.
