export async function setupSandbox(pages) {
  const res = await pages[0].request.post("http://127.0.0.1:4002/sandbox");
  const token = await res.text();
  await Promise.all(
    pages.map((p) => p.setExtraHTTPHeaders({ "user-agent": token })),
  );
}

export async function setupScenario(page, scenario) {
  const res = await page.request.post("http://127.0.0.1:4002/test/setup", {
    data: { scenario },
  });
  return await res.json();
}

export async function login(page, user_id) {
  const res = await page.request.post("http://127.0.0.1:4002/test/login", {
    data: { user_id },
  });

  const cookieHeader = res.headers()["set-cookie"];
  const value = cookieHeader.split(";")[0].split("=").slice(1).join("=");
  await page.context().addCookies([
    {
      name: "_stop_my_hand_key",
      value,
      domain: "localhost",
      path: "/",
    },
  ]);
}

export async function teardownSandbox(page) {
  await page.request.delete("http://127.0.0.1:4002/sandbox");
}
