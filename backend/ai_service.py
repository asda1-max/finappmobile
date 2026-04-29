"""AI Service — OpenRouter integration for Tick Watchers.

Provides LLM-powered stock analysis chat and decision explanation
via the OpenRouter API (compatible with any model they host).
"""

from __future__ import annotations

import os
import json
from typing import Optional

import httpx


OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
OPENROUTER_MODEL = os.environ.get("OPENROUTER_MODEL", "google/gemma-4-31b-it")
OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"

# ── Timeouts ──
_TIMEOUT = httpx.Timeout(timeout=120.0, connect=15.0)


def is_configured() -> bool:
    """Check if the OpenRouter API key is properly configured."""
    return bool(OPENROUTER_API_KEY and OPENROUTER_API_KEY != "your-openrouter-api-key-here")


async def chat_completion(
    system_prompt: str,
    user_message: str,
    *,
    model: Optional[str] = None,
    max_tokens: int = 1536,
    temperature: float = 0.7,
) -> str:
    """Send a chat completion request to OpenRouter.

    Returns the assistant's response text, or raises on error.
    """
    if not is_configured():
        return (
            "⚠️ OpenRouter API key belum dikonfigurasi.\n\n"
            "Silakan set `OPENROUTER_API_KEY` di file `backend/.env` "
            "lalu restart server."
        )

    effective_model = model or OPENROUTER_MODEL

    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://tick-watchers.app",
        "X-Title": "Tick Watchers AI",
    }

    payload = {
        "model": effective_model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        "max_tokens": max_tokens,
        "temperature": temperature,
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        response = await client.post(
            f"{OPENROUTER_BASE_URL}/chat/completions",
            headers=headers,
            json=payload,
        )

        if response.status_code != 200:
            error_body = response.text
            raise RuntimeError(
                f"OpenRouter API error {response.status_code}: {error_body}"
            )

        data = response.json()
        choices = data.get("choices") or []
        if not choices:
            raise RuntimeError("OpenRouter returned empty choices")

        return choices[0]["message"]["content"]


# ── System Prompts ──

_CHAT_SYSTEM_PROMPT = """Kamu adalah AI Stock Analyst untuk aplikasi "Tick Watchers" — sebuah Decision Making Support System untuk saham Indonesia (IDX).

IDENTITAS:
- Nama: Tick AI
- Spesialisasi: Analisis fundamental saham Indonesia
- Bahasa: Kamu bisa berbicara dalam Bahasa Indonesia dan English. Ikuti bahasa yang dipakai user.

KONTEKS DATA:
Berikut adalah data fundamental saham yang sedang dianalisis user. Gunakan data ini sebagai basis analisismu — JANGAN mengkarang angka.

{stock_context}

METODE KEPUTUSAN:
Aplikasi menggunakan metode MCDM (Multi-Criteria Decision Making):
- Hybrid Fuzzy AHP-TOPSIS adalah metode utama keputusan BUY/NO BUY
- Hybrid Score (0-1): semakin tinggi semakin layak beli
- Kategori: "Recommended to Buy" > "Buy" > "Buy with Risk" > "Don't Buy"
- Quality Score: kualitas fundamental perusahaan (Premium/Solid/Standard/Weak)
- Discount Score: seberapa murah harga saat ini vs historis
- MOS (Margin of Safety): selisih harga pasar vs Graham Number (positif = undervalued)

FAKTOR YANG DIANALISIS:
- ROE (Return on Equity) — efisiensi modal
- PER (Price Earning Ratio) — valuasi harga vs laba
- PBV (Price to Book Value) — valuasi harga vs nilai buku
- MOS — margin of safety Graham Number
- EPS (Earning Per Share) — laba per lembar saham
- Dividend Yield & Growth — pendapatan dividen
- CAGR (Revenue, Net Income, EPS) — pertumbuhan historis
- Down From High 52W — diskon dari harga tertinggi 1 tahun

ATURAN:
1. SELALU berikan analisis berbasis data yang tersedia. Jangan spekulasi tanpa dasar.
2. Jelaskan KENAPA, bukan hanya APA.
3. Jika user bertanya tentang saham yang tidak ada di data, jelaskan bahwa kamu hanya bisa menganalisis saham yang sudah di-track di watchlist.
4. Gunakan emoji secara wajar untuk readability (📊 📈 📉 ✅ ⚠️ ❌ 💡).
5. Untuk perbandingan, selalu gunakan tabel atau poin-poin terstruktur.
6. Tutup dengan insight actionable yang jelas.
7. Keep responses concise tapi informatif. Jangan terlalu panjang."""


_EXPLAIN_SYSTEM_PROMPT = """Kamu adalah AI yang menjelaskan keputusan investasi dari aplikasi "Tick Watchers".

Tugasmu adalah menjelaskan MENGAPA model Fuzzy AHP-TOPSIS memberikan keputusan tertentu untuk sebuah saham, dalam bahasa yang mudah dipahami investor retail Indonesia.

Data saham:
{stock_data}

ATURAN:
1. Jelaskan dalam 3-5 poin utama mengapa saham ini mendapat keputusan tersebut.
2. Setiap poin harus merujuk ke metrik spesifik (ROE, PBV, MOS, dll.) dengan angkanya.
3. Sertakan ⚠️ risiko jika ada kelemahan meskipun keputusan BUY.
4. Sertakan 💡 insight jika ada peluang meskipun keputusan NO BUY.
5. Akhiri dengan 1 kalimat ringkasan actionable.
6. Gunakan Bahasa Indonesia.
7. Format sebagai poin-poin bernomor. Singkat dan padat.
8. JANGAN mengarang angka — hanya gunakan data yang diberikan."""


def build_stock_context(stocks: list[dict]) -> str:
    """Build a compact stock context string for the system prompt.

    Takes a list of stock dicts (from the /stocks endpoint response)
    and formats them as a readable context block.
    """
    if not stocks:
        return "(Tidak ada data saham di watchlist saat ini)"

    lines = []
    for s in stocks:
        ticker = s.get("Ticker", "???")
        name = s.get("Name", "-")
        price = s.get("Price", 0)
        sector = s.get("Sector", "-")

        # Core metrics
        roe = s.get("ROE (%)", 0)
        per = s.get("PER NOW", 0)
        pbv = s.get("PBV", 0)
        mos = s.get("MOS (%)", 0)
        eps = s.get("EPS NOW", 0)
        graham = s.get("Graham Number", 0)

        # Scores
        quality_score = s.get("Quality Score", 0)
        quality_label = s.get("Quality Label", "-")
        discount_score = s.get("Discount Score", 0)

        # Hybrid decision
        hybrid_score = s.get("Absolute Hybrid Score") or s.get("Base Hybrid Score") or s.get("Hybrid Score") or 0
        hybrid_cat = s.get("Final Hybrid Category") or s.get("Base Hybrid Category") or s.get("Hybrid Category") or "-"
        decision = s.get("Execution Decision") or s.get("Final Decision Buy") or s.get("Decision Buy") or "NO BUY"

        # Price momentum
        down_high = s.get("Down From High 52 (%)", 0)
        down_month = s.get("Down From This Month (%)", 0)
        rise_low = s.get("Rise From Low 52 (%)", 0)

        # Dividends
        div_yield = s.get("Dividend Yield (%)", 0)
        div_growth = s.get("Dividend Growth (%)", 0)
        payout = s.get("Payout Ratio (%)", 0)

        # CAGR
        cagr_ni = s.get("CAGR Net Income Used (%)")
        cagr_rev = s.get("CAGR Revenue Used (%)")
        cagr_eps = s.get("CAGR EPS Used (%)")
        cagr_applied = s.get("CAGR Applied", False)

        # Safety verdicts
        safety = s.get("Safety Check")
        quality_verdict = s.get("Quality Verdict")
        timing_verdict = s.get("Discount Timing Verdict")

        # Additional fundamentals
        npm = s.get("Net Profit Margin (%)")
        de = s.get("Debt To Equity (%)")
        cr = s.get("Current Ratio")
        mcap = s.get("Market Cap", 0)

        block = (
            f"── {ticker} ({name}) ──\n"
            f"  Sektor: {sector} | Harga: Rp {price:,.0f} | Mkt Cap: {mcap:,.0f}\n"
            f"  Keputusan: {decision} | Hybrid Score: {hybrid_score:.3f} | Kategori: {hybrid_cat}\n"
            f"  Quality Score: {quality_score:.2f} ({quality_label}) | Discount Score: {discount_score:.2f}\n"
            f"  ROE: {roe:.1f}% | PER: {per:.1f}x | PBV: {pbv:.2f}x | MOS: {mos:.1f}%\n"
            f"  EPS: {eps:.2f} | Graham Number: {graham:,.0f}\n"
            f"  Down From 52W High: {down_high:.1f}% | Down From Month: {down_month:.1f}% | Rise From Low: {rise_low:.1f}%\n"
        )

        if div_yield and div_yield > 0:
            block += f"  Div Yield: {div_yield:.2f}% | Div Growth: {div_growth:.1f}% | Payout: {payout:.1f}%\n"

        if cagr_applied and cagr_ni is not None:
            block += f"  CAGR Net Income: {cagr_ni:.1f}% | Revenue: {cagr_rev:.1f}% | EPS: {cagr_eps:.1f}%\n"

        extras = []
        if npm is not None:
            extras.append(f"NPM: {npm:.1f}%")
        if de is not None:
            extras.append(f"D/E: {de:.1f}%")
        if cr is not None:
            extras.append(f"Current Ratio: {cr:.2f}")
        if extras:
            block += f"  {' | '.join(extras)}\n"

        if safety:
            block += f"  ⚠️ Safety: {safety}\n"
        if quality_verdict:
            block += f"  Quality Verdict: {quality_verdict}\n"
        if timing_verdict:
            block += f"  Timing Verdict: {timing_verdict}\n"

        lines.append(block)

    return "\n".join(lines)


def get_chat_system_prompt(stocks: list[dict]) -> str:
    """Build the full chat system prompt with stock context injected."""
    context = build_stock_context(stocks)
    return _CHAT_SYSTEM_PROMPT.format(stock_context=context)


def get_explain_system_prompt(stock_dict: dict) -> str:
    """Build the explain system prompt for a single stock."""
    data_str = build_stock_context([stock_dict])
    return _EXPLAIN_SYSTEM_PROMPT.format(stock_data=data_str)
