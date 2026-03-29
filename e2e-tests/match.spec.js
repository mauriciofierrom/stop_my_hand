import { test, expect } from "@playwright/test";
import {
  setupSandbox,
  setupScenario,
  login,
  teardownSandbox,
} from "./support/setup_scenario.js";

test.afterEach(async ({ page }) => {
  await teardownSandbox(page);
});

test("player gets other player's activity", async ({ browser }) => {
  const context1 = await browser.newContext();
  const page1 = await context1.newPage();
  await setupSandbox(page1);
  const { match_id, creator, players } = await setupScenario(
    page1,
    "match_lobby",
  );
  await login(page1, creator.id);
  await page1.goto(`/lobby/${match_id}`);

  const context2 = await browser.newContext();
  const page2 = await context2.newPage();
  await setupSandbox(page2);
  await login(page2, players[0].id);
  await page2.goto(`/lobby/${match_id}`);
  await page2.waitForURL(`/lobby/${match_id}`);

  const btn = page1.getByRole("button", { name: "Play" });
  await expect(btn).toBeEnabled({ timeout: 15000 });
  await btn.click();
  await page1.waitForURL(`/match/${match_id}`);
  await page2.waitForURL(`/match/${match_id}`);

  await expect(page1.locator("#letter")).not.toBeEmpty();
  const letter = await page1.locator("#letter").textContent();
  await expect(page1.getByLabel("Name", { exact: true })).toBeEnabled();
  await page1.getByLabel("Name", { exact: true }).fill(`${letter}xx`);
  await page1.getByLabel("Last Name", { exact: true }).focus();

  await expect(page2.getByTestId(`name-activity-${creator.id}`)).toHaveText(
    letter.repeat(3),
  );
});
