def _apply_fuzzy_ahp_topsis_buy_decision(df: pd.DataFrame) -> pd.DataFrame:
    """Terapkan Hybrid FUZZY AHP-TOPSIS untuk keputusan BUY/NO BUY di dashboard.

    Menggunakan mesin yang sama dengan detailed CAGR (decision_making.py).
    Evaluasi dilakukan secara BATCH (semua ticker sekaligus) agar TOPSIS
    bisa membandingkan secara relatif antar ticker, bukan fallback absolut.

    Perbaikan vs versi sebelumnya:
    - Batch evaluation (bukan per-ticker)
    - down_from_high dimasukkan ke CagrResult
    - quality_score dan discount_score dimasukkan ke CagrResult
    - Quality gate: quality < 0.4 + BUY → downgrade ke NO BUY
    """

    if df is None or len(df) == 0:
        return df

    required_cols = [
        "MOS (%)",
        "ROE (%)",
        "PBV",
        "Dividend Yield (%)",
        "PER NOW",
    ]

    # Jika kolom penting tidak lengkap, biarkan keputusan lama apa adanya
    if not all(col in df.columns for col in required_cols):
        return df

    cagr_items = _load_cagr_items()

    _QUALITY_GATE_THRESHOLD = 0.4  # Quality di bawah ini → downgrade BUY ke NO BUY

    base_results = []
    final_results = []
    has_cagr_dict = {}

    for idx, row in df.iterrows():
        ticker = str(row.get("Ticker") or row.get("Name") or "-")

        roe = float(row.get("ROE (%)") or 0.0)
        mos = float(row.get("MOS (%)") or 0.0)
        pbv = float(row.get("PBV") or 0.0)
        div_yield = float(row.get("Dividend Yield (%)") or 0.0)
        per = float(row.get("PER NOW") or 0.0)
        down_from_high = float(row.get("Down From High 52 (%)") or 0.0)
        qscore = float(row.get("Quality Score") or 0.0)
        discount_score = float(row.get("Discount Score") or 0.0)

        base_result = CagrResult(
            ticker=ticker,
            cagr_net_income=0.0,
            cagr_revenue=0.0,
            cagr_eps=0.0,
            roe=roe,
            mos=mos,
            pbv=pbv,
            div_yield=div_yield,
            per=per,
            down_from_high=down_from_high,
            quality_score=qscore,
            discount_score=discount_score,
        )
        base_results.append(base_result)

        cagr_net, cagr_rev, cagr_eps, has_cagr = _extract_cagr_for_ticker(ticker, cagr_items)
        cagr_source = "saved"

        if not has_cagr:
            auto_net = pd.to_numeric(row.get("Auto CAGR Net Income (%)"), errors="coerce")
            auto_rev = pd.to_numeric(row.get("Auto CAGR Revenue (%)"), errors="coerce")
            auto_eps = pd.to_numeric(row.get("Auto CAGR EPS (%)"), errors="coerce")
            if not pd.isna(auto_net) and not pd.isna(auto_rev) and not pd.isna(auto_eps):
                cagr_net = float(auto_net)
                cagr_rev = float(auto_rev)
                cagr_eps = float(auto_eps)
                has_cagr = True
                cagr_source = "auto_live"

        has_cagr_dict[ticker] = {
            "has_cagr": has_cagr,
            "cagr_source": cagr_source,
            "cagr_net": cagr_net if has_cagr else 0.0,
            "cagr_rev": cagr_rev if has_cagr else 0.0,
            "cagr_eps": cagr_eps if has_cagr else 0.0,
        }

        if has_cagr:
            final_result = CagrResult(
                ticker=ticker,
                cagr_net_income=cagr_net,
                cagr_revenue=cagr_rev,
                cagr_eps=cagr_eps,
                roe=roe,
                mos=mos,
                pbv=pbv,
                div_yield=div_yield,
                per=per,
                down_from_high=down_from_high,
                quality_score=qscore,
                discount_score=discount_score,
            )
        else:
            final_result = base_result

        final_results.append(final_result)

    # Lakukan evaluasi secara BATCH untuk semua ticker agar pemeringkatan relatif valid
    base_eval = evaluate_cagr_methods(base_results, use_cagr=False)
    final_eval = evaluate_cagr_methods(final_results, use_cagr=True)

    base_methods = base_eval.get("methods", {}).get("FUZZY_AHP_TOPSIS", {})
    final_methods = final_eval.get("methods", {}).get("FUZZY_AHP_TOPSIS", {})

    for idx, row in df.iterrows():
        ticker = str(row.get("Ticker") or row.get("Name") or "-")
        qscore = float(row.get("Quality Score") or 0.0)
        cagr_info = has_cagr_dict.get(ticker, {})
        has_cagr = cagr_info.get("has_cagr", False)
        cagr_source = cagr_info.get("cagr_source", "none")
        cagr_net = cagr_info.get("cagr_net", 0.0)
        cagr_rev = cagr_info.get("cagr_rev", 0.0)
        cagr_eps = cagr_info.get("cagr_eps", 0.0)

        base_info = base_methods.get(ticker, {})
        base_decision = base_info.get("decision")
        base_score = base_info.get("score")
        base_category = base_info.get("category")

        if has_cagr:
            final_info = final_methods.get(ticker, {})
        else:
            final_info = base_info

        final_decision = final_info.get("decision")
        final_score = final_info.get("score")
        final_category = final_info.get("category")

        # ── Quality Gate ──
        # Jika quality terlalu rendah, downgrade BUY ke NO BUY
        if qscore < _QUALITY_GATE_THRESHOLD:
            if base_decision == "BUY":
                base_decision = "NO BUY"
                base_category = "Don't Buy"
            if final_decision == "BUY":
                final_decision = "NO BUY"
                final_category = "Don't Buy"

        # Tulis ke DataFrame
        df.at[idx, "CAGR Applied"] = bool(has_cagr)
        df.at[idx, "CAGR Source"] = cagr_source if has_cagr else "none"
        if has_cagr:
            df.at[idx, "CAGR Net Income Used (%)"] = float(cagr_net)
            df.at[idx, "CAGR Revenue Used (%)"] = float(cagr_rev)
            df.at[idx, "CAGR EPS Used (%)"] = float(cagr_eps)

        if base_decision:
            df.at[idx, "Decision Buy"] = base_decision
            df.at[idx, "Base Decision Buy"] = base_decision
        if base_score is not None:
            df.at[idx, "Hybrid Score"] = float(base_score)
            df.at[idx, "Base Hybrid Score"] = float(base_score)
        if base_category:
            df.at[idx, "Hybrid Category"] = str(base_category)
            df.at[idx, "Base Hybrid Category"] = str(base_category)
        df.at[idx, "Hybrid Mode"] = "no_cagr"

        if final_decision:
            df.at[idx, "Final Decision Buy"] = final_decision
        if final_score is not None:
            df.at[idx, "Final Hybrid Score"] = float(final_score)
        if final_category:
            df.at[idx, "Final Hybrid Category"] = str(final_category)
        df.at[idx, "Final Hybrid Mode"] = "with_cagr" if has_cagr else "no_cagr"

    return df
