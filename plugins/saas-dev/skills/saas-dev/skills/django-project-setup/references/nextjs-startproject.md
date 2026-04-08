# Project Setup: Next.js Project Creation

## Invoked when user selects Next.js App Router or Pages Router in Phase 0

---

## App Router (Next.js 13+, modern standard)

```bash
cd /path/to/project-root

npx create-next-app@latest frontend
# Answer prompts:
# ✔ TypeScript?           → Yes
# ✔ ESLint?               → Yes
# ✔ Tailwind CSS?         → Yes
# ✔ src/ directory?       → Yes
# ✔ App Router?           → Yes   ← App Router
# ✔ Turbopack?            → Yes   (faster dev builds)
# ✔ Customize import alias? → Yes → @/*

cd frontend

# Install additional dependencies
npm install zustand swr
npm install react-hook-form @hookform/resolvers zod
npm install next-auth            # NextAuth.js v4 stable (works for both App + Pages Router)
npm install clsx tailwind-merge
npx shadcn@latest init          # component library

# Create .env.local
cat > .env.local << 'ENVEOF'
DJANGO_API_URL=http://localhost:8000
AUTH_SECRET=
NEXT_PUBLIC_APP_NAME=MyApp
ENVEOF

# Create .env.example (commit this)
cat > .env.example << 'ENVEOF'
DJANGO_API_URL=http://localhost:8000
AUTH_SECRET=generate-with-openssl-rand-base64-32
NEXT_PUBLIC_APP_NAME=MyApp
ENVEOF

echo "✓ Next.js App Router project created at frontend/"
```

---

## Pages Router (legacy, still widely used)

```bash
npx create-next-app@latest frontend
# ✔ TypeScript?           → Yes
# ✔ ESLint?               → Yes
# ✔ Tailwind CSS?         → Yes
# ✔ src/ directory?       → Yes
# ✔ App Router?           → No   ← Pages Router
# ✔ Customize import alias? → Yes → @/*

cd frontend

npm install @reduxjs/toolkit react-redux
npm install react-hook-form @hookform/resolvers zod
npm install swr
npm install next-auth             # NextAuth.js v4 (Pages Router)
npm install cookies-next          # cookie helper for API routes
npm install clsx tailwind-merge
npx shadcn@latest init

cat > .env.local << 'ENVEOF'
DJANGO_API_URL=http://localhost:8000
NEXTAUTH_URL=http://localhost:3000
AUTH_SECRET=
NEXT_PUBLIC_APP_NAME=MyApp
ENVEOF
```

---

## Monorepo structure (when Django + Next.js in same repo)

```
project-root/
├── backend/          ← Django project (manage.py, config/, apps/)
│   ├── .venv/
│   ├── requirements.txt
│   └── manage.py
├── frontend/         ← Next.js project
│   ├── src/
│   ├── package.json
│   └── next.config.ts
├── docker-compose.yml
└── CLAUDE.md
```

## Separate repos (when Django + Next.js in different repos)

```
backend-repo/     ← Django only
  ├── .venv/
  ├── requirements.txt
  └── manage.py

frontend-repo/    ← Next.js only
  ├── src/
  ├── package.json
  └── .env.local  (DJANGO_API_URL points to deployed backend)
```

---

## Generate AUTH_SECRET

```bash
# Mac/Linux
openssl rand -base64 32

# Windows (PowerShell)
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

---

## Verify setup

```bash
# From frontend/ directory
npm run dev
# Expected: Next.js dev server at http://localhost:3000

# In another terminal: Django
cd ../backend
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
python manage.py runserver
# Expected: Django at http://localhost:8000
```
