# Olist E-Commerce Analysis: What Drives Satisfaction and Repeat Purchases?

An end-to-end SQL analysis of ~100,000 orders from Olist, a Brazilian e-commerce marketplace, to answer:
**What drives customer satisfaction and repeat purchases, and what should Olist prioritize to improve them?**

**Tools:** SQL (DuckDB) · Python (pandas, matplotlib) · Jupyter

---

## TL;DR

- **Late deliveries are the biggest driver of bad reviews.** Only 6.7% of orders arrive late, but they cause ~37% of all 1-star reviews.
- **Customers judge Olist on keeping its promise, not on speed.** Early deliveries earn almost no extra credit, but reviews drop sharply as soon as the estimated date is missed.
- **Most delays happen after the seller hands off the package.** 78% of late orders were shipped on time by the seller, pointing to carrier performance and unrealistic estimates.
- **Retention is extremely low and is a separate problem.** Only ~2.2% of customers truly return, and a good or bad first order makes no meaningful difference. What they buy matters more.

---

## Recommendations

1. **Make delivery estimates realistic where they're failing.** Late rates reach 12–18% in the Northeast (MA, CE, BA) and Rio de Janeiro. Recalibrating estimates using actual carrier performance in these regions would cut late orders without making delivery any faster.
2. **Prioritize Rio de Janeiro.** RJ is the second-largest market (12k+ orders) with a 12% late rate despite moderate delivery times. Because of its volume, it produces more late orders than six high-rate Northeast states combined.
3. **Use missed seller handoffs as an early-warning system.** Orders handed to the carrier late arrive late 27% of the time, about 5x the normal rate. Flagging these orders gives Olist days to expedite or notify the customer before the estimate passes, while reviews are still salvageable.
4. **Partner with high-volume sellers, and coach the outliers.** The top 100 sellers handle ~42% of orders and ~50% of late deliveries. Improving shipping and estimates with this group reaches half of all late orders. A small number of sellers run 2–3x the average late rate and are worth addressing directly.
5. **Build retention as its own strategy.** Fixing delivery will improve satisfaction, but it won't bring customers back on its own. Focus re-engagement on the first 90 days after a purchase (when ~55% of genuine returns happen) and on categories with natural repeat behavior: fashion accessories, pet supplies, and home goods.

---

## Key Findings

### 1. Growth came entirely from new customers
| Jan–Aug | Orders | Revenue | Avg. order value |
|---|---|---|---|
| 2017 | 22,562 | R$3.57M | R$158 |
| 2018 | 53,531 | R$8.59M | R$161 |

Revenue grew 140% year over year, driven almost entirely by order volume (+137%) while average order value stayed flat. Growth plateaued at ~6–7k orders/month through 2018.

### 2. Late delivery drives bad reviews
| Delivery | Share of orders | Avg. review | 1-star rate |
|---|---|---|---|
| On time or early | 93.3% | 4.29 | 6.6% |
| Late | 6.7% | 2.27 | 53.8% |

Reviews fall by nearly a full star at just 1–3 days late (~3.3), drop to ~2.1 at 4–7 days late, and bottom out around 1.7 after a week. Arriving early earns little extra credit.

### 3. Lateness is regional and systemic
- **Highest late rates:** Maranhão (17.5%), Ceará (13.8%), Bahia (12.2%), Rio de Janeiro (12.1%)
- **São Paulo** is fastest (8.7 days avg.) with a 4.5% late rate, but its volume still makes it the largest source of late orders
- **Long delivery ≠ late:** Mato Grosso averages 18 days but is only 6% late, because its estimates account for distance
- **78% of late orders** were handed to the carrier on time. Late seller handoffs account for ~22%
- The 15 worst high-volume sellers account for only ~7% of late orders, so this is not a "few bad sellers" problem

### 4. Retention is rare and unrelated to first-order experience
- 96.9% of customers ordered only once in the raw data
- ~30% of apparent repeat customers placed their second order **on the same day** (multi-seller checkouts split into separate orders). Correcting for this, the **true repeat rate is ~2.2%**
- Return rates were essentially flat across first-order review scores (1-star vs. 5-star difference not statistically significant)
- First-order category matters more: fashion accessories (5.1%), pet supplies (4.2%), and home goods (3.8%) bring customers back most; gifts, games, and office furniture least (~1.7–1.8%)

---

## Approach

**1. Data quality** ([`01_setup_and_data_quality.ipynb`](01_setup_and_data_quality.ipynb)): loaded all 9 tables into DuckDB and validated keys, nulls, and relationships before any analysis.

**2. Analysis** ([`02_analysis.ipynb`](02_analysis.ipynb)): built an order-level view (one row per order) to prevent double counting, then analyzed growth, delivery performance, reviews, sellers, and retention.

SQL techniques used: CTEs, window functions (`ROW_NUMBER`, `LAG`, `LEAD`, running totals with `SUM() OVER`), views, conditional aggregation, and multi-table joins.

### Data quality issues found and handled
- **Customer IDs:** `customer_id` is unique per *order*, not per person. All retention analysis uses `customer_unique_id` (96,096 real customers).
- **Duplicate reviews:** 547 orders had multiple reviews (customers can update reviews). Kept the most recent per order with `ROW_NUMBER`.
- **Join fan-out:** joining items and payments together overstated payments by ~28%. Aggregating each to the order level first reconciled item revenue and payments to within 0.02%.
- **Same-day "repeat" orders:** redefined a returning customer as one who ordered again on a *later* date.
- **Incomplete periods:** restricted analysis to Jan 2017–Aug 2018 (2016 is sparse launch data; Sep 2018 is incomplete).
- **Censoring:** retention analysis only includes first orders through Feb 2018, so every customer had 6+ months to return.
- **Minor inconsistencies:** 8 delivered orders with no delivery date and 6 canceled orders with one; excluded from delivery analysis.

---

## Limitations
- Findings are associations, not proven causes. Late orders may differ in other ways (e.g., remote destinations) that also affect reviews.
- Olist mainly sells through larger marketplaces, so many customers may not know they bought from Olist, which likely contributes to low retention in ways this data can't measure.
- For orders with multiple products, category is based on the first item.
- Data covers 2016–2018 and may not reflect Olist's current operations.

---

## Reproduce This Analysis
1. Download the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) from Kaggle
2. Place the CSV files in a `data/` folder in the project root
3. Install dependencies: `pip install duckdb pandas matplotlib`
4. Run `01_setup_and_data_quality.ipynb`, then `02_analysis.ipynb`
