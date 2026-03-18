#!/usr/bin/env bash
# deploy.sh — interactive brand setup → config.json → rebrand → git → GitHub
#
# Usage:
#   bash deploy.sh            # fully interactive (all prompts)
#   bash deploy.sh --help     # show this help

set -euo pipefail

# ── colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}▸${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $*"; }
die()   { echo -e "${RED}✗  $*${NC}" >&2; exit 1; }

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: bash deploy.sh"
  echo "  Interactively collects brand info, writes config.json,"
  echo "  rebuilds index.html, and pushes to a new GitHub repo."
  exit 0
fi

# ── locate node ─────────────────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
  NODE_PATHS=(
    "/c/Program Files/nodejs/node.exe"
    "/c/Program Files/nodejs/node"
    "$HOME/.nvm/versions/node/*/bin/node"
  )
  NODE_BIN=""
  for p in "${NODE_PATHS[@]}"; do
    if [ -f "$p" ]; then NODE_BIN="$p"; break; fi
  done
  [ -n "$NODE_BIN" ] || die "node not found. Install Node.js and try again."
  export PATH="$(dirname "$NODE_BIN"):$PATH"
fi

command -v git  &>/dev/null || die "git not found."
command -v node &>/dev/null || die "node not found."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

[ -f rebrand.js    ] || die "rebrand.js not found."
[ -f template.html ] || die "template.html not found. Run: node rebrand.js --init"

# ── prompt helper ────────────────────────────────────────────────────────────
# ask <VAR> <Label> [default]  — required if no default supplied
ask() {
  local var="$1" label="$2" default="${3:-}" val
  if [ -n "$default" ]; then
    read -rp "$(echo -e "  ${CYAN}${label}${NC} [${default}]: ")" val
    val="${val:-$default}"
  else
    read -rp "$(echo -e "  ${CYAN}${label}${NC}: ")" val
    while [ -z "$val" ]; do
      echo -e "  ${RED}Required — please enter a value.${NC}"
      read -rp "$(echo -e "  ${CYAN}${label}${NC}: ")" val
    done
  fi
  printf -v "$var" '%s' "$val"
}

# ── gather inputs ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Brand Setup — press Enter to accept [default]       ${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}── Company ─────────────────────────────────────────${NC}"
ask BUSINESS_NAME "Business name"                        "Artisan"
ask TAGLINE       "Tagline (e.g. Steel Roofing)"         "Steel Roofing"
ask CITY          "City"                                  "Moncton"
ask PROVINCE      "Province / State"                      "New Brunswick"
ask REGION        "Service region (short, for body copy)" "Maritime Provinces"
ask ADDRESS       "Address line (footer)"                 "${CITY}, ${PROVINCE}"
echo ""

echo -e "${BOLD}── Contact ─────────────────────────────────────────${NC}"
ask PHONE  "Phone number"   "(506) 555-0199"
DEFAULT_EMAIL="info@$(echo "$BUSINESS_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ').ca"
ask EMAIL  "Email address"  "$DEFAULT_EMAIL"
echo ""

echo -e "${BOLD}── History ─────────────────────────────────────────${NC}"
ask YEARS  "Years in business"              "25"
ask SINCE  "In business since (year)"       "1999"
ask ROOFS  "Roofs completed (e.g. 500+)"    "500+"
echo ""

echo -e "${BOLD}── Messaging ───────────────────────────────────────${NC}"
ask HERO_TAG      "Hero tag line"          "${CITY}'s #1 ${TAGLINE} Company"
ask FOOTER_REGION "Footer region tagline"  "${CITY}, Riverview, Dieppe, and all of ${REGION}"
echo ""

echo -e "${BOLD}── Colors ──────────────────────────────────────────${NC}"
echo -e "  (Enter hex codes, e.g. #C8880A. Dark variants are auto-derived.)"
ask PRIMARY_HEX   "Primary accent color (CTAs, highlights)"  "#C8880A"
ask SECONDARY_HEX "Secondary brand color (sections, accents)" "#475936"
echo ""

echo -e "${BOLD}── Services ────────────────────────────────────────${NC}"
echo -e "  (Comma-separated list for the footer services column)"
DEFAULT_SERVICES="Residential Roofing,Commercial Roofing,Emergency Repairs,Roof Inspections,Flashings & Trim,Re-Roofing"
ask SERVICES_RAW "Services" "$DEFAULT_SERVICES"
echo ""

echo -e "${BOLD}── GitHub ──────────────────────────────────────────${NC}"
DEFAULT_SLUG="$(echo "$BUSINESS_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g; s/[^a-z0-9-]//g')"
ask REPO_SLUG  "GitHub repo slug"          "$DEFAULT_SLUG"
ask VISIBILITY "Repo visibility"           "private"
echo ""

# ── summary ──────────────────────────────────────────────────────────────────
echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Summary                                             ${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"
echo -e "  Business : ${CYAN}${BUSINESS_NAME}${NC} — ${TAGLINE}"
echo -e "  Location : ${CITY}, ${PROVINCE}"
echo -e "  Phone    : ${PHONE}  |  Email: ${EMAIL}"
echo -e "  Colors   : primary ${PRIMARY_HEX}  secondary ${SECONDARY_HEX}"
echo -e "  Repo     : ${REPO_SLUG} (${VISIBILITY})"
echo ""
read -rp "$(echo -e "  ${BOLD}Proceed? [Y/n]:${NC} ")" CONFIRM
CONFIRM="${CONFIRM:-Y}"
[[ "$CONFIRM" =~ ^[Yy] ]] || { warn "Aborted."; exit 0; }
echo ""

# ── 1. generate config.json ──────────────────────────────────────────────────
info "Generating config.json..."

export BUSINESS_NAME TAGLINE CITY PROVINCE REGION ADDRESS
export PHONE EMAIL YEARS SINCE ROOFS HERO_TAG FOOTER_REGION
export PRIMARY_HEX SECONDARY_HEX SERVICES_RAW

node - <<'NODESCRIPT'
const fs = require('fs');

// ── color helpers ────────────────────────────────────────────────────────────
function hexToRgb(hex) {
  const h = hex.replace('#', '');
  return [
    parseInt(h.slice(0, 2), 16),
    parseInt(h.slice(2, 4), 16),
    parseInt(h.slice(4, 6), 16)
  ];
}
function rgbToHex(r, g, b) {
  return '#' + [r, g, b]
    .map(x => Math.min(255, Math.max(0, Math.round(x))).toString(16).padStart(2, '0'))
    .join('');
}
function darken(hex, factor) {
  const [r, g, b] = hexToRgb(hex);
  return rgbToHex(r * factor, g * factor, b * factor);
}

// ── pull env vars ────────────────────────────────────────────────────────────
const name      = (process.env.BUSINESS_NAME || 'Artisan').trim();
const tagline   = (process.env.TAGLINE       || 'Steel Roofing').trim();
const city      = (process.env.CITY          || 'Moncton').trim();
const province  = (process.env.PROVINCE      || 'New Brunswick').trim();
const region    = (process.env.REGION        || 'Maritime Provinces').trim();
const address   = (process.env.ADDRESS       || `${city}, ${province}`).trim();
const phone     = (process.env.PHONE         || '').trim();
const email     = (process.env.EMAIL         || '').trim();
const years     = (process.env.YEARS         || '25').trim();
const since     = (process.env.SINCE         || '1999').trim();
const roofs     = (process.env.ROOFS         || '500+').trim();
const heroTag   = (process.env.HERO_TAG      || `${city}'s #1 ${tagline} Company`).trim();
const footerRgn = (process.env.FOOTER_REGION || city).trim();
const primary   = (process.env.PRIMARY_HEX   || '#C8880A').trim();
const secondary = (process.env.SECONDARY_HEX || '#475936').trim();

// ── services → HTML ──────────────────────────────────────────────────────────
const services = (process.env.SERVICES_RAW || '')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);
const servicesHtml = services
  .map(s => `<li><a href="#">${s}</a></li>`)
  .join('\n          ');

// ── assemble config ──────────────────────────────────────────────────────────
const cfg = {
  seo: {
    title: `${name} – ${tagline} – ${city}`
  },
  company: {
    name,
    tagline,
    city,
    province,
    region,
    address,
    phone,
    email,
    yearsInBusiness: years,
    since,
    roofsCompleted:  roofs,
    copyrightYear:   String(new Date().getFullYear()),
    footerRegion:    footerRgn
  },
  hero: {
    tag: heroTag
  },
  reviews: {
    rating: '4.9',
    count:  '200+'
  },
  services: {
    html: servicesHtml
  },
  colors: {
    bark:       darken(secondary, 0.72),   // darkened secondary
    green:      secondary,
    amber:      primary,
    amberDark:  darken(primary, 0.78),     // darkened primary
    sand:       '#C4A882',
    parchment:  '#F5F0E8',
    dark:       '#1E1E1E',
    mid:        '#2D2D2D',
    textGray:   '#717171'
  }
};

fs.writeFileSync('config.json', JSON.stringify(cfg, null, 2) + '\n', 'utf8');
console.log(`  wrote ${Object.keys(cfg).length} sections, ${Object.keys(cfg.company).length} company fields`);
NODESCRIPT

ok "config.json generated."

# ── 2. run rebrand ───────────────────────────────────────────────────────────
info "Running rebrand (template.html → index.html)..."
node rebrand.js
ok "index.html rebuilt."

# ── 3. git init ──────────────────────────────────────────────────────────────
if [ ! -d ".git" ]; then
  info "Initialising git repository..."
  git init -b main
  ok "Git repo initialised."
else
  info "Git repo already exists."
fi

# ── 4. .gitignore ────────────────────────────────────────────────────────────
if [ ! -f ".gitignore" ]; then
  cat > .gitignore <<'GITIGNORE'
node_modules/
temporary screenshots/
*.tmp
.DS_Store
Thumbs.db
GITIGNORE
  ok ".gitignore created."
fi

# ── 5. stage and commit ──────────────────────────────────────────────────────
info "Staging files..."
git add index.html template.html config.json rebrand.js deploy.sh serve.mjs screenshot.mjs .gitignore CLAUDE.md 2>/dev/null || true
git add Brand_Assets/ 2>/dev/null || true

COMMIT_MSG="rebrand: ${BUSINESS_NAME}"
if git diff --cached --quiet; then
  warn "Nothing new to commit (all files already up to date)."
else
  git commit -m "$COMMIT_MSG"
  ok "Committed: ${COMMIT_MSG}"
fi

# ── 6. push to GitHub ────────────────────────────────────────────────────────
if command -v gh &>/dev/null; then
  info "Creating GitHub repository '${REPO_SLUG}' (${VISIBILITY})..."

  if gh repo view "$REPO_SLUG" &>/dev/null 2>&1; then
    warn "Repo '${REPO_SLUG}' already exists on GitHub — pushing to existing repo."
    REMOTE_URL="$(gh repo view "$REPO_SLUG" --json sshUrl -q '.sshUrl' 2>/dev/null \
                  || gh repo view "$REPO_SLUG" --json url -q '.url')"
  else
    gh repo create "$REPO_SLUG" \
      "--${VISIBILITY}" \
      --source=. \
      --remote=origin \
      --push \
      --description "Website for ${BUSINESS_NAME}" 2>/dev/null \
    && ok "GitHub repo created and pushed." \
    && exit 0
    REMOTE_URL="$(gh repo view "$REPO_SLUG" --json sshUrl -q '.sshUrl' 2>/dev/null \
                  || gh repo view "$REPO_SLUG" --json url -q '.url')"
  fi

  if git remote get-url origin &>/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
  else
    git remote add origin "$REMOTE_URL"
  fi

  info "Pushing to GitHub..."
  git push -u origin main
  ok "Pushed to ${REMOTE_URL}"

else
  echo ""
  warn "GitHub CLI (gh) not found. To push manually:"
  echo ""
  echo "  1. Create a repo at https://github.com/new"
  echo "     Name: ${REPO_SLUG}  |  Visibility: ${VISIBILITY}"
  echo ""
  echo "  2. Then run:"
  echo "     git remote add origin https://github.com/YOUR_USERNAME/${REPO_SLUG}.git"
  echo "     git push -u origin main"
  echo ""
  echo "  Install gh CLI: https://cli.github.com/"
fi

echo ""
ok "${BOLD}Done!${NC} Site is ready at http://localhost:3000"
