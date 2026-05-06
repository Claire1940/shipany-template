#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ENV="${TARGET_ENV:?TARGET_ENV is required}"
CONFIG_FILE="${1:-}"
OUTPUT_FILE="${2:-}"
CDP_PORT="${CDP_PORT:-9224}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-${SCRIPT_DIR}/tmp/screenshots}"
AGENT_BROWSER="${AGENT_BROWSER:-agent-browser}"

mkdir -p "${SCRIPT_DIR}/tmp" "${SCREENSHOT_DIR}"

if [ -z "${CONFIG_FILE}" ] || [ ! -f "${CONFIG_FILE}" ]; then
  printf 'Usage: TARGET_ENV=<sandbox|production> %s <products.json> [output.env]\n' "$0" >&2
  exit 1
fi

if [ -z "${OUTPUT_FILE}" ]; then
  OUTPUT_FILE="${SCRIPT_DIR}/tmp/creem-${TARGET_ENV}.env"
fi

run_browser() {
  "${AGENT_BROWSER}" --cdp "${CDP_PORT}" "$@"
}

screenshot() {
  local name="$1"
  run_browser screenshot "${SCREENSHOT_DIR}/creem-${TARGET_ENV}-${name}-$(date +%s).png" >/dev/null
}

js_string() {
  node -e 'process.stdout.write(JSON.stringify(process.argv[1] || ""))' "$1"
}

json_get() {
  local expr="$1"
  node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const v=(${expr}); if (v === undefined || v === null) process.exit(2); process.stdout.write(String(v));" "${CONFIG_FILE}"
}

json_products() {
  node - <<'NODE' "${CONFIG_FILE}"
const fs = require('fs');
const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
for (const p of data.products || []) console.log(JSON.stringify(p));
NODE
}

click_text() {
  local text="$1" quoted
  quoted="$(js_string "$text")"
  run_browser eval "(()=>{const target=${quoted}; const els=[...document.querySelectorAll('button,a,[role=menuitem],div,span')]; const el=els.find(x=>(x.innerText||x.textContent||'').trim()===target); if(!el) throw new Error('not found: '+target); el.click(); return target;})()" >/dev/null
}

click_contains() {
  local text="$1" quoted
  quoted="$(js_string "$text")"
  run_browser eval "(()=>{const target=${quoted}; const els=[...document.querySelectorAll('button,a,[role=menuitem],div,span')]; const el=els.find(x=>(x.innerText||x.textContent||'').includes(target)); if(!el) throw new Error('not found contains: '+target); el.click(); return target;})()" >/dev/null
}

fill_visible_input_by_index() {
  local index="$1" value="$2" quoted
  quoted="$(js_string "$value")"
  run_browser eval "(()=>{const inputs=[...document.querySelectorAll('input')].filter(x=>x.type!=='file' && x.offsetParent!==null); const el=inputs[${index}]; if(!el) throw new Error('input index not found: ${index}'); el.focus(); el.value=''; el.dispatchEvent(new Event('input',{bubbles:true})); el.value=${quoted}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); return true;})()" >/dev/null
}

fill_textarea_by_index() {
  local index="$1" value="$2" quoted
  quoted="$(js_string "$value")"
  run_browser eval "(()=>{const els=[...document.querySelectorAll('textarea')].filter(x=>x.offsetParent!==null); const el=els[${index}]; if(!el) throw new Error('textarea index not found: ${index}'); el.focus(); el.value=''; el.dispatchEvent(new Event('input',{bubbles:true})); el.value=${quoted}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); return true;})()" >/dev/null
}

copy_product_id() {
  local title="$1" quoted
  quoted="$(js_string "$title")"
  run_browser eval "(()=>{const rows=[...document.querySelectorAll('tr,[role=row]')]; let row=rows.find(r=>(r.innerText||'').includes(${quoted})); if(!row){const cells=[...document.querySelectorAll('td,[role=cell],div')]; const cell=cells.find(c=>(c.innerText||'').trim()===${quoted}); row=cell?.closest('tr,[role=row]') || cell?.parentElement;} if(!row) throw new Error('product row not found: '+${quoted}); const buttons=[...row.querySelectorAll('button')]; const menu=buttons.find(b=>(b.innerText||b.textContent||'').includes('Toggle menu')) || buttons[buttons.length-1]; if(!menu) throw new Error('menu button not found'); menu.click(); return true;})()" >/dev/null
  run_browser wait 500 >/dev/null
  click_text "Copy Product ID"
  run_browser wait 500 >/dev/null
  run_browser clipboard read | tr -d '\n'
}

is_sandbox_mode() {
  run_browser eval "document.body.innerText.includes('Using sandbox data')" | grep -q true
}

ensure_environment() {
  run_browser open "https://www.creem.io/dashboard/home" >/dev/null
  run_browser wait 3000 >/dev/null
  screenshot "home"

  if [ "${TARGET_ENV}" = "sandbox" ]; then
    if is_sandbox_mode; then
      return 0
    fi
    click_contains "Test Mode"
    run_browser wait 2500 >/dev/null
    if run_browser eval "document.body.innerText.includes('Enable Test Mode')" | grep -q true; then
      click_contains "Enable Test Mode"
      run_browser wait 4000 >/dev/null
    fi
    if ! is_sandbox_mode; then
      printf 'Failed to switch Creem dashboard into sandbox mode.\n' >&2
      exit 1
    fi
    return 0
  fi

  if is_sandbox_mode; then
    for label in "Stop Using Test Mode" "Disable Test Mode" "Exit Test Mode" "Use Live Mode" "Live Mode"; do
      if run_browser eval "document.body.innerText.includes($(js_string "${label}"))" | grep -q true; then
        click_contains "${label}"
        run_browser wait 4000 >/dev/null
        break
      fi
    done
  fi

  if is_sandbox_mode; then
    printf 'Creem dashboard is still in sandbox mode. Switch to Live mode in the dashboard, then rerun.\n' >&2
    exit 1
  fi
}

create_product() {
  local product_json="$1"
  local title description billing_type amount image_path billing_period
  title="$(node -e 'const p=JSON.parse(process.argv[1]); process.stdout.write(p.title)' "${product_json}")"
  description="$(node -e 'const p=JSON.parse(process.argv[1]); process.stdout.write(p.description || "")' "${product_json}")"
  billing_type="$(node -e 'const p=JSON.parse(process.argv[1]); process.stdout.write(p.billing_type || "one-time")' "${product_json}")"
  amount="$(node -e 'const p=JSON.parse(process.argv[1]); process.stdout.write(String(p.amount))' "${product_json}")"
  image_path="$(node -e 'const p=JSON.parse(process.argv[1]); process.stdout.write(p.image || "")' "${product_json}")"
  billing_period="$(node -e 'const p=JSON.parse(process.argv[1]); process.stdout.write(p.billing_period || "")' "${product_json}")"

  if [ -z "${image_path}" ] || [ ! -f "${image_path}" ]; then
    printf 'Missing image for product: %s (%s)\n' "${title}" "${image_path}" >&2
    exit 1
  fi

  run_browser open "https://www.creem.io/dashboard/products/new" >/dev/null
  run_browser wait 2500 >/dev/null
  screenshot "${title// /-}-new"

  run_browser fill 'input[placeholder="Name"]' "${title}" >/dev/null
  fill_textarea_by_index 0 "${description}"

  if [ "${billing_type}" = "subscription" ]; then
    click_text "Subscription"
    run_browser wait 800 >/dev/null
  else
    click_text "Single Payment"
    run_browser wait 800 >/dev/null
  fi

  fill_visible_input_by_index 2 "${amount}"

  if [ "${billing_type}" = "subscription" ] && [ -n "${billing_period}" ]; then
    click_contains "Monthly"
    run_browser wait 500 >/dev/null
    click_text "${billing_period}"
    run_browser wait 500 >/dev/null
  fi

  run_browser upload 'input[type=file]' "${image_path}" >/dev/null
  run_browser wait 7000 >/dev/null
  screenshot "${title// /-}-filled"
  click_text "Create Product"
  run_browser wait 5000 >/dev/null
  screenshot "${title// /-}-created"
}

create_api_key_if_needed() {
  local api_key_name
  api_key_name="$(json_get 'data.api_key_name')"
  run_browser open "https://www.creem.io/dashboard/developers" >/dev/null
  run_browser wait 3000 >/dev/null
  if run_browser eval "document.body.innerText.includes($(js_string "${api_key_name}"))" | grep -q true; then
    printf ''
    return 0
  fi
  click_contains "Create API Key"
  run_browser wait 1500 >/dev/null
  run_browser fill 'input[placeholder="e.g. Production Backend"]' "${api_key_name}" >/dev/null
  click_contains "Full Access"
  run_browser wait 500 >/dev/null
  click_text "Create Key"
  run_browser wait 2500 >/dev/null
  screenshot "api-key-created"
  click_text "Copy"
  run_browser wait 500 >/dev/null
  run_browser clipboard read | tr -d '\n'
  click_text "Done"
  run_browser wait 1000 >/dev/null
}

create_or_open_webhook() {
  local name url
  name="$(json_get 'data.webhook.name')"
  url="$(json_get 'data.webhook.url')"
  run_browser open "https://www.creem.io/dashboard/developers" >/dev/null
  run_browser wait 2500 >/dev/null
  click_text "Webhooks"
  run_browser wait 1500 >/dev/null

  if run_browser eval "document.body.innerText.includes($(js_string "${url}"))" | grep -q true; then
    run_browser eval "(()=>{const rows=[...document.querySelectorAll('tr,[role=row]')]; const row=rows.find(r=>(r.innerText||'').includes($(js_string "${url}"))); if(!row) throw new Error('existing webhook row not found'); row.click(); return true;})()" >/dev/null
  else
    click_contains "Add Webhook"
    run_browser wait 1500 >/dev/null
    run_browser fill 'input[placeholder="My Webhook"]' "${name}" >/dev/null
    run_browser fill 'input[placeholder="https://your-domain.com/webhook"]' "${url}" >/dev/null
    run_browser eval "(()=>{const wanted=new Set(['checkout.completed','subscription.active','subscription.canceled','subscription.paid','subscription.update','subscription.paused']); const rows=[...document.querySelectorAll('div')].filter(x=>/^([a-z]+\.)/.test((x.innerText||'').trim())); for(const row of rows){const text=(row.innerText||'').trim(); const cb=row.querySelector('input[type=checkbox]'); if(!cb) continue; const selected=[...wanted].some(w=>text.startsWith(w)); if(selected && !cb.checked) cb.click(); if(!selected && cb.checked) cb.click();} return true;})()" >/dev/null
    run_browser wait 500 >/dev/null
    screenshot "webhook-filled"
    click_text "Save Webhook"
    run_browser wait 3000 >/dev/null
  fi
  screenshot "webhook-detail"
  run_browser eval "(()=>{const inputs=[...document.querySelectorAll('input')]; const secret=inputs.find(i=>i.value && /^\*+$/.test(i.value)); const btn=secret?.parentElement?.querySelector('button') || [...document.querySelectorAll('button')].find(b=>(b.innerText||'').includes('Copy')); if(!btn) throw new Error('webhook secret copy button not found'); btn.click(); return true;})()" >/dev/null
  run_browser wait 500 >/dev/null
  run_browser clipboard read | tr -d '\n'
}

ensure_environment

while IFS= read -r product; do
  create_product "${product}"
done < <(json_products)

run_browser open "https://www.creem.io/dashboard/products" >/dev/null
run_browser wait 3000 >/dev/null
screenshot "products-final"

products_map='{}'
while IFS= read -r product; do
  key="$(node -e 'const p=JSON.parse(process.argv[1]); process.stdout.write(p.product_id)' "${product}")"
  title="$(node -e 'const p=JSON.parse(process.argv[1]); process.stdout.write(p.title)' "${product}")"
  id="$(copy_product_id "${title}")"
  products_map="$(node -e 'const map=JSON.parse(process.argv[1]); map[process.argv[2]]=process.argv[3].trim(); process.stdout.write(JSON.stringify(map));' "${products_map}" "${key}" "${id}")"
done < <(json_products)

api_key="$(create_api_key_if_needed || true)"
webhook_secret="$(create_or_open_webhook)"
placeholder_prefix="creem_"
if [ "${TARGET_ENV}" = "sandbox" ]; then
  placeholder_prefix="creem_test_"
fi

{
  printf 'SELECT_PAYMENT_ENABLED=false\n'
  printf 'DEFAULT_PAYMENT_PROVIDER=creem\n'
  printf 'STRIPE_ENABLED=false\n'
  printf 'PAYPAL_ENABLED=false\n'
  printf 'CREEM_ENABLED=true\n'
  printf 'CREEM_ENVIRONMENT=%s\n' "${TARGET_ENV}"
  if [ -n "${api_key}" ]; then
    printf 'CREEM_API_KEY=%s\n' "${api_key}"
  else
    printf 'CREEM_API_KEY=<%sapi_key>\n' "${placeholder_prefix}"
  fi
  printf 'CREEM_SIGNING_SECRET=%s\n' "${webhook_secret}"
  printf 'CREEM_PRODUCT_IDS=%s\n' "${products_map}"
} > "${OUTPUT_FILE}"

chmod 600 "${OUTPUT_FILE}"
printf 'Creem %s output written to %s\n' "${TARGET_ENV}" "${OUTPUT_FILE}"
printf 'Screenshots saved under %s\n' "${SCREENSHOT_DIR}"
