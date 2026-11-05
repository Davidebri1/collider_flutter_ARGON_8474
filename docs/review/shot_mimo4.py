import asyncio
from playwright.async_api import async_playwright

OUT = r"C:\Users\D\Documents\collider-source-Mimo\docs\review"

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel="chrome", headless=True)
        page = await browser.new_page(viewport={"width": 390, "height": 844}, device_scale_factor=3)
        await page.goto("http://localhost:8901/", wait_until="networkidle")
        await page.wait_for_timeout(9000)
        await page.screenshot(path=OUT + r"\mimo_home2.png")
        print("home v2 saved")
        await browser.close()

asyncio.run(main())
