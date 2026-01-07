import { test, expect } from '@playwright/test';
import path from 'path';

test('can upload a video and it appears on homepage', async ({ page }) => {
  await page.goto('http://localhost:3000/upload');

  const filePath = path.join(__dirname, '..', 'fixtures', 'blank.mp4');
  const input = await page.locator('input[type=file]');
  await input.setInputFiles(filePath);

  await page.click('button:has-text("Upload")');

  // Wait for processing finished message or redirect
  await page.waitForTimeout(3000);

  // Navigate to home and confirm file exists
  await page.goto('http://localhost:3000/');

  const fileName = 'blank.mp4';
  await expect(page.locator(`text=${fileName}`)).toBeVisible();
});