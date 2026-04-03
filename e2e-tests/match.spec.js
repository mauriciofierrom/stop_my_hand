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

test.describe("match round", () => {
  let letter;
  let page1;
  let page2;
  let creatorPlayer;
  let allPlayers;

  test("player can review a player's answers", async ({browser}) => {
    const context1 = await browser.newContext();
    page1 = await context1.newPage();
    const context2 = await browser.newContext();
    page2 = await context2.newPage();
    await setupSandbox([page1, page2]);
    const { match_id, creator, players } = await setupScenario(
      page1,
      "match_lobby",
    );

    creatorPlayer = creator;
    allPlayers = players;

    await login(page1, creator.id);
    await page1.goto(`/lobby/${match_id}`);
    await page1.waitForURL(`/lobby/${match_id}`);
    await login(page2, players[0].id);
    await page2.goto(`/lobby/${match_id}`);
    await page2.waitForURL(`/lobby/${match_id}`);

    const btn = page1.getByRole("button", { name: "Play" });
    await expect(btn).toBeEnabled({ timeout: 15000 });
    await btn.click();
    await page1.waitForURL(`/match/${match_id}`);
    await page2.waitForURL(`/match/${match_id}`);

    await expect(page1.locator("#letter")).not.toBeEmpty({timeout: 10000});
    letter = await page1.locator("#letter").textContent();
    await expect(page1.getByLabel("Name", { exact: true })).toBeEnabled();
    const categories = [
      "name",
      "last_name",
      "city",
      "color",
      "animal",
      "thing",
    ];

    const fields = await page1.locator('input[type="text"]').all();
    const fields2 = await page2.locator('input[type="text"]').all();

    for (const input of fields) {
      await input.fill(letter.repeat(3));
    }

    for (const input of fields2) {
      await input.fill(letter.repeat(3));
    }

    await fields.at(-1).press("Enter");

    for (const category of categories.slice(0, -1)) {
      await page2
        .getByTestId(`accept-button-${category}`)
        .click();
      await page1
        .getByTestId(`accept-button-${category}`)
        .click();
    }

    await page2.getByTestId("reject-button-thing").click();
    await page1.getByTestId("reject-button-thing").click();

    for (const category of categories.slice(0, -1)) {
      await expect(page2.getByTestId(`score-${category}-${allPlayers[0].id}`)).toHaveText("50");
      await expect(page1.getByTestId(`score-${category}-${creatorPlayer.id}`)).toHaveText("50");
    }

    await expect(page2.getByTestId(`score-${categories.at(-1)}-${allPlayers[0].id}`)).toHaveText("0");
    await expect(page1.getByTestId(`score-${categories.at(-1)}-${creatorPlayer.id}`)).toHaveText("0");
  });
});
