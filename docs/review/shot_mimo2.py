import asyncio
from playwright.async_api import async_playwright

OUT = r"C:\Users\D\Documents\collider-source-Mimo\docs\review"

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel="chrome", headless=True)
        page = await browser.new_page(viewport={"width": 390, "height": 844}, device_scale_factor=3)
        await page.goto("http://localhost:8901/", wait_until="networkidle")
        await page.wait_for_timeout(8000)
        await page.mouse.click(233, 807)   # dock: apps grid
        await page.wait_for_timeout(2500)
        await page.mouse.click(93, 351)    # Smart Gen tile
        await page.wait_for_timeout(5000)
        await page.screenshot(path=OUT + r"\mimo_smartgen2.png")
        print("smartgen v2 saved")
        await browser.close()

asyncio.run(main())
