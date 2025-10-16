(function () {
  // --- PHẦN 1: DỌN DẸP POPUP CŨ (NẾU CÓ) ---
  if (document.getElementById("my-workspace-popup-container")) {
    document.getElementById("my-workspace-popup-container").remove();
    document.getElementById("my-workspace-popup-overlay").remove();
    const old_styles = document.querySelector('style[data-popup-style="true"]');
    if (old_styles) old_styles.remove();
    if (window.showDashboard) delete window.showDashboard;
  }

  // --- PHẦN 2: CÁC HÀM TIỆN ÍCH VÀ LOGIC CỐT LÕI ---

  let keepAliveIntervalId = null;

  function closeAllActionMenus() {
    document
      .querySelectorAll(".action-menu-dropdown")
      .forEach((menu) => menu.remove());
  }

  function logMessage(message, type = "info") {
    const logBox = document.getElementById("log-history-box");
    if (!logBox) {
      console.log(message);
      return;
    }
    const timestamp = new Date().toLocaleTimeString("en-GB");
    const logEntry = document.createElement("div");
    logEntry.className = `log-entry log-${type}`;
    const timeSpan = document.createElement("span");
    timeSpan.textContent = `[${timestamp}]`;
    const textNode = document.createTextNode(` ${message}`);
    logEntry.appendChild(timeSpan);
    logEntry.appendChild(textNode);
    logBox.appendChild(logEntry);
    logBox.scrollTop = logBox.scrollHeight;
  }

  function decodeJwtPayload(token) {
    if (!token) return null;
    try {
      const base64Url = token.split(".")[1];
      if (!base64Url) return null;
      const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
      const jsonPayload = decodeURIComponent(
        atob(base64)
          .split("")
          .map(function (c) {
            return "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2);
          })
          .join("")
      );
      return JSON.parse(jsonPayload);
    } catch (e) {
      logMessage(`Lỗi khi giải mã token: ${e.message}`, "error");
      return null;
    }
  }

  const getSAPISIDHASH = async () => {
    const n = Math.floor(Date.now() / 1e3),
      s = document.cookie
        .split("; ")
        .find((r) => r.startsWith("SAPISID="))
        ?.split("=")[1];
    if (!s) return "";
    const o = location.origin,
      i = `${n} ${s} ${o}`,
      t = new TextEncoder(),
      d = t.encode(i),
      a = await crypto.subtle.digest("SHA-1", d);
    return `${n}_${Array.from(new Uint8Array(a))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("")}`;
  };

  const callWorkspaceAPI = async ({ endpoint: e, body: t }) => {
    const s = await getSAPISIDHASH();
    const a = await fetch(
      `https://monospace-pa.clients6.google.com/$rpc/google.internal.developerexperience.webide.v1.WorkspaceService/${e}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json+protobuf",
          "X-Goog-Api-Key": "AIzaSyDsw6ox_fmME37xw9qQhmv6MJW53CD7O68",
          Authorization: `SAPISIDHASH ${s}`,
          Origin: location.origin,
          Referer: location.href,
          "X-Goog-AuthUser": "0",
        },
        body: JSON.stringify(t),
        credentials: "include",
      }
    );
    return a.json();
  };

  async function getToken(name) {
    const res = await callWorkspaceAPI({
      endpoint: "GenerateWorkstationAccessToken",
      body: [name],
    });
    return Array.isArray(res) ? res[0] : null;
  }

  async function getWorkspaceLiveStatus(name, host, token) {
    if (!host || !token) return "warning";
    const url = `https://csx.googleidx.click/proxy?url=${encodeURIComponent(
      `https://${host}?time=${Date.now()}`
    )}`;
    try {
      const response = await fetch(url, {
        method: "GET",
        headers: { "x-auth-token": `${token}` },
      });
      if (response.status === 200) return "running";
      if (response.status === 404) {
        logMessage(
          `[Live Check] Workspace ${name} trả về 404, đang yêu cầu mở lại...`,
          "info"
        );
        callWorkspaceAPI({ endpoint: "OpenWorkspace", body: [name] });
        return "stopped";
      }
      return "warning";
    } catch (e) {
      logMessage(
        `[Live Check] Lỗi mạng khi kiểm tra ${name}: ${e.message}`,
        "error"
      );
      return "warning";
    }
  }

  async function refreshDashboard() {
    const tableBody = document.querySelector(
      "#my-workspace-popup-content table tbody"
    );
    if (tableBody) {
      const firstLoad = !tableBody.dataset.loaded;
      if (firstLoad) {
        tableBody.dataset.loaded = "true";
        while (tableBody.firstChild) {
          tableBody.removeChild(tableBody.firstChild);
        }
        const loadingRow = document.createElement("tr");
        const loadingCell = document.createElement("td");
        loadingCell.colSpan = 4;
        loadingCell.textContent = "Đang tải danh sách workspaces...";
        loadingCell.style.textAlign = "center";
        loadingRow.appendChild(loadingCell);
        tableBody.appendChild(loadingRow);
        logMessage("Bắt đầu làm mới danh sách Workspaces...");
      }
    }

    try {
      const data = await callWorkspaceAPI({
        endpoint: "ListWorkspaces",
        body: [],
      });
      const initialWorkspaces = data[0];
      logMessage(
        `[Refresh] Tìm thấy ${initialWorkspaces.length} workspace. Bắt đầu kiểm tra trạng thái live...`
      );
      const workspaces = await Promise.all(
        initialWorkspaces.map(async (item) => {
          const name = item[0] || "Unknown";
          let host = item[2] || null;
          const token = await getToken(name);
          if (!host && token) {
            const payload = decodeJwtPayload(token);
            if (payload && payload.aud) {
              host = payload.aud;
              logMessage(`[Info] Lấy host cho '${name}' từ token.`, "info");
            }
          }
          const liveStatus = await getWorkspaceLiveStatus(name, host, token);
          return {
            name,
            createEmail: item[11] || "N/A",
            host: host || "N/A",
            status: liveStatus,
            token,
          };
        })
      );
      renderTable(workspaces);
      logMessage(
        "[Refresh] Kiểm tra live và tải danh sách thành công!",
        "success"
      );
    } catch (e) {
      logMessage(`[Refresh] Lỗi khi tải dữ liệu: ${e.message}`, "error");
      console.error("Lỗi CORS hoặc API:", e);
    }
  }

  function renderTable(workspaces) {
    const tableBody = document.querySelector(
      "#my-workspace-popup-content table tbody"
    );
    while (tableBody.firstChild) {
      tableBody.removeChild(tableBody.firstChild);
    }
    if (workspaces.length === 0) {
      const row = document.createElement("tr");
      const cell = document.createElement("td");
      cell.colSpan = 4;
      cell.textContent = "Không tìm thấy workspace nào.";
      cell.style.textAlign = "center";
      row.appendChild(cell);
      tableBody.appendChild(row);
      return;
    }
    workspaces.forEach((ws) => {
      const row = document.createElement("tr");
      row.dataset.workspaceName = ws.name;
      const nameCell = document.createElement("td");
      const statusDot = document.createElement("span");
      statusDot.className = `status-dot ${ws.status}`;
      statusDot.title = ws.status.charAt(0).toUpperCase() + ws.status.slice(1);
      nameCell.appendChild(statusDot);
      nameCell.appendChild(document.createTextNode(ws.name));
      const emailCell = document.createElement("td");
      emailCell.textContent = ws.createEmail;
      const hostCell = document.createElement("td");
      hostCell.textContent = ws.host;
      const actionsCell = document.createElement("td");
      actionsCell.className = "actions-cell";
      const copyBtn = document.createElement("button");
      copyBtn.textContent = "📋";
      copyBtn.title = "Copy Access URL";
      copyBtn.onclick = () => {
        if (!ws.host || !ws.token) {
          logMessage(
            `Không thể tạo URL: Thiếu host hoặc token cho ${ws.name}.`,
            "error"
          );
          return;
        }
        const urlToCopy = `https://${ws.host}/env/msg?_workstationAccessToken=${ws.token}`;
        navigator.clipboard.writeText(urlToCopy);
        logMessage(`Đã sao chép URL cho ${ws.name}.`);
      };
      const deleteBtn = document.createElement("button");
      deleteBtn.textContent = "🗑️";
      deleteBtn.title = "Delete Workspace";
      deleteBtn.onclick = async () => {
        if (
          confirm(
            `Bạn có chắc muốn xóa vĩnh viễn workspace "${ws.name}" không?`
          )
        ) {
          logMessage(`Đang yêu cầu xóa workspace "${ws.name}"...`);
          deleteBtn.disabled = true;
          try {
            await callWorkspaceAPI({
              endpoint: "DeleteWorkspace",
              body: [ws.name],
            });
            logMessage(
              `Đã xóa thành công "${ws.name}"! Đang làm mới...`,
              "success"
            );
            await refreshDashboard();
          } catch (error) {
            logMessage(`Lỗi khi xóa "${ws.name}": ${error.message}`, "error");
            deleteBtn.disabled = false;
          }
        }
      };
      const menuBtn = document.createElement("button");
      menuBtn.textContent = "⋮";
      menuBtn.title = "More Actions";
      menuBtn.onclick = (event) => {
        event.stopPropagation();
        closeAllActionMenus();
        const rect = menuBtn.getBoundingClientRect();
        const menu = document.createElement("div");
        menu.className = "action-menu-dropdown";
        menu.style.top = `${rect.bottom + 5}px`;
        menu.style.left = `${rect.left - 50}px`;
        const currentStatus = row
          .querySelector(".status-dot")
          .classList.contains("running")
          ? "running"
          : "stopped";
        const actionText = currentStatus === "running" ? "Stop" : "Start";
        const actionIcon = actionText === "Start" ? "▶️" : "⏹️";
        const endpoint =
          actionText === "Start" ? "OpenWorkspace" : "StopWorkspace";
        const body = actionText === "Start" ? [ws.name] : [ws.name, []];
        const actionButton = document.createElement("button");
        actionButton.textContent = `${actionIcon} ${actionText}`;
        actionButton.onclick = async () => {
          logMessage(`Đang thực thi ${actionText} cho "${ws.name}"...`);
          actionButton.disabled = true;
          actionButton.textContent = "...";
          try {
            await callWorkspaceAPI({ endpoint, body });
            logMessage(
              `Thực thi ${actionText} thành công! Đang làm mới...`,
              "success"
            );
            setTimeout(() => refreshDashboard(), 2000);
          } catch (error) {
            logMessage(`Lỗi khi ${actionText}: ${error.message}`, "error");
          } finally {
            closeAllActionMenus();
          }
        };
        menu.appendChild(actionButton);
        document.body.appendChild(menu);
      };
      actionsCell.appendChild(copyBtn);
      actionsCell.appendChild(deleteBtn);
      actionsCell.appendChild(menuBtn);
      [nameCell, emailCell, hostCell, actionsCell].forEach((cell) =>
        row.appendChild(cell)
      );
      tableBody.appendChild(row);
    });
  }

  // --- PHẦN 3: TẠO CẤU TRÚC POPUP (HTML) ---
  const overlay = document.createElement("div");
  overlay.id = "my-workspace-popup-overlay";
  const container = document.createElement("div");
  container.id = "my-workspace-popup-container";
  const header = document.createElement("div");
  header.className = "popup-header";
  const title = document.createElement("h2");
  title.textContent = "Workspace Dashboard";
  const closeBtn = document.createElement("button");
  closeBtn.className = "popup-close-btn";
  closeBtn.textContent = "×";
  header.appendChild(title);
  header.appendChild(closeBtn);
  const content = document.createElement("div");
  content.id = "my-workspace-popup-content";
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headerRow = document.createElement("tr");
  const tbody = document.createElement("tbody");
  ["Name", "Create Email", "Host", "Actions"].forEach((text) => {
    const th = document.createElement("th");
    th.textContent = text;
    headerRow.appendChild(th);
  });
  thead.appendChild(headerRow);
  const initialRow = document.createElement("tr");
  const initialCell = document.createElement("td");
  initialCell.colSpan = 4;
  initialCell.style.textAlign = "center";
  initialCell.textContent = "Đang tải dữ liệu, vui lòng chờ...";
  initialRow.appendChild(initialCell);
  tbody.appendChild(initialRow);
  table.appendChild(thead);
  table.appendChild(tbody);
  content.appendChild(table);
  const logSection = document.createElement("div");
  logSection.className = "log-section";
  const logHeader = document.createElement("div");
  logHeader.className = "log-section-header";
  logHeader.textContent = "📜 Lịch sử Log & Bảng điều khiển";
  const logContentWrapper = document.createElement("div");
  logContentWrapper.className = "log-content-wrapper";
  const logBox = document.createElement("div");
  logBox.id = "log-history-box";
  const controlPanel = document.createElement("div");
  controlPanel.id = "control-panel";
  const panelTitle = document.createElement("h4");
  panelTitle.textContent = "Giữ Active & Tự động Refresh";
  const panelDesc = document.createElement("p");
  panelDesc.textContent =
    'Tự động làm mới toàn bộ bảng và giữ các workspace đang chạy không bị "ngủ".';
  const startKeepAliveBtn = document.createElement("button");
  startKeepAliveBtn.id = "start-keep-alive-btn";
  startKeepAliveBtn.textContent = "Bắt đầu Tự động Refresh";
  const stopKeepAliveBtn = document.createElement("button");
  stopKeepAliveBtn.id = "stop-keep-alive-btn";
  stopKeepAliveBtn.textContent = "Dừng";
  stopKeepAliveBtn.disabled = true;
  controlPanel.appendChild(panelTitle);
  controlPanel.appendChild(panelDesc);
  controlPanel.appendChild(startKeepAliveBtn);
  controlPanel.appendChild(stopKeepAliveBtn);
  logContentWrapper.appendChild(logBox);
  logContentWrapper.appendChild(controlPanel);
  logSection.appendChild(logHeader);
  logSection.appendChild(logContentWrapper);
  container.appendChild(header);
  container.appendChild(content);
  container.appendChild(logSection);

  // --- PHẦN 4: ĐỊNH DẠNG GIAO DIỆN (CSS) ---
  const styles = `
    :root { --primary-blue: #007bff; --light-grey: #f8f9fa; --border-color: #dee2e6; --text-color: #212529; --white: #fff; --green-status: #28a745; --red-status: #dc3545; --grey-status: #6c757d; --log-bg: #212529; --log-text: #f8f9fa; --warning-status: #ffc107; }
    #my-workspace-popup-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(0, 0, 0, 0.5); z-index: 9998; backdrop-filter: blur(4px); }
    #my-workspace-popup-container { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 85%; max-width: 1600px; height: 90vh; background-color: var(--white); color: var(--text-color); border-radius: 8px; box-shadow: 0 5px 25px rgba(0,0,0,0.2); z-index: 9999; display: flex; flex-direction: column; border: 1px solid var(--border-color); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }
    #my-workspace-popup-content th { background-color: var(--light-grey); font-weight: 600; position: sticky; top: 0; z-index: 1; }
    .status-dot.running { background-color: var(--green-status); } .status-dot.stopped { background-color: var(--red-status); } .status-dot.warning { background-color: var(--warning-status); }
    /* ... Các CSS cũ khác ... */
    .popup-header { display: flex; justify-content: space-between; align-items: center; padding: 12px 20px; background-color: var(--primary-blue); color: var(--white); border-bottom: 1px solid var(--border-color); border-radius: 8px 8px 0 0; } .popup-header h2 { margin: 0; font-size: 1.4em; } .log-section { border-top: 1px solid var(--border-color); height: 400px; display: flex; flex-direction: column; } .log-section-header { padding: 8px 15px; font-weight: 600; background-color: var(--light-grey); } .log-content-wrapper { display: flex; flex-direction: row; flex-grow: 1; min-height: 0; } #log-history-box { background-color: var(--log-bg); color: var(--log-text); padding: 10px; font-family: "SF Mono", "Fira Code", "Consolas", monospace; font-size: 0.85em; overflow-y: auto; flex: 1; min-width: 0; } #control-panel { flex: 0 0 300px; padding: 15px; border-left: 1px solid var(--border-color); background-color: var(--light-grey); display: flex; flex-direction: column; } #control-panel h4 { margin-top: 0; } #control-panel p { font-size: 0.9em; color: #6c757d; flex-grow: 1;} #control-panel button { padding: 10px; cursor: pointer; border: 1px solid #ccc; border-radius: 4px; margin-top: 5px; } #control-panel button:disabled { cursor: not-allowed; background-color: #e9ecef; } #start-keep-alive-btn { background-color: #28a745; color: white; border-color: #28a745; } #stop-keep-alive-btn { background-color: #dc3545; color: white; border-color: #dc3545; } .log-entry.log-success { color: #28a745; } .log-entry.log-error { color: #dc3545; } .popup-close-btn:hover { opacity: 1; } #my-workspace-popup-content { padding: 0; overflow-y: auto; flex-grow: 1; } #my-workspace-popup-content table { width: 100%; border-collapse: collapse; } #my-workspace-popup-content th, #my-workspace-popup-content td { padding: 12px 15px; border-bottom: 1px solid var(--border-color); text-align: left; vertical-align: middle; white-space: nowrap; } .popup-close-btn { background: none; border: none; font-size: 2em; color: var(--white); cursor: pointer; padding: 0; line-height: 1; opacity: 0.8; } #my-workspace-popup-content td { font-size: 0.95em; } #my-workspace-popup-content tr:last-child td { border-bottom: none; } .status-dot { height: 10px; width: 10px; border-radius: 50%; display: inline-block; margin-right: 8px; } .actions-cell { text-align: center !important; } .actions-cell button { background: none; border: none; cursor: pointer; font-size: 1.2em; margin: 0 5px; padding: 2px; opacity: 0.7; transition: opacity 0.2s; } .actions-cell button:hover { opacity: 1; } .actions-cell button:disabled { opacity: 0.3; cursor: not-allowed; } .log-entry span { color: #888; margin-right: 10px; } .action-menu-dropdown { position: absolute; background-color: var(--white); border: 1px solid var(--border-color); border-radius: 6px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); z-index: 10000; padding: 5px; } .action-menu-dropdown button { display: block; width: 100%; padding: 8px 12px; text-align: left; font-size: 0.9em; margin: 0; opacity: 1; } .action-menu-dropdown button:hover { background-color: var(--light-grey); }
  `;
  const styleSheet = document.createElement("style");
  styleSheet.setAttribute("data-popup-style", "true");
  styleSheet.textContent = styles;
  document.head.appendChild(styleSheet);

  // --- PHẦN 5: GẮN POPUP, CHẠY VÀ GÁN SỰ KIỆN ---

  startKeepAliveBtn.onclick = async () => {
    if (keepAliveIntervalId) {
      logMessage("Tiến trình Tự động Refresh đã chạy rồi.", "info");
      return;
    }
    logMessage("Bắt đầu tiến trình Tự động Refresh...", "info");
    startKeepAliveBtn.disabled = true;
    stopKeepAliveBtn.disabled = false;
    await refreshDashboard();
    keepAliveIntervalId = setInterval(async () => {
      const str = new Date().toLocaleString("vi-VN", { hour12: false });
      logMessage(`[Auto-Refresh] Bắt đầu chu kỳ lúc ${str}.`, "info");
      await refreshDashboard();
    }, 80 * 1000);
  };

  stopKeepAliveBtn.onclick = () => {
    if (keepAliveIntervalId) {
      clearInterval(keepAliveIntervalId);
      keepAliveIntervalId = null;
      logMessage("Đã dừng tiến trình Tự động Refresh.", "info");
      startKeepAliveBtn.disabled = false;
      stopKeepAliveBtn.disabled = true;
    }
  };

  const showDashboard = async () => {
    overlay.style.display = "block";
    container.style.display = "flex";
    logMessage("Dashboard được hiện lại.", "info");
  };

  const hideDashboard = () => {
    overlay.style.display = "none";
    container.style.display = "none";
    logMessage(
      "Dashboard đã được ẩn. Tiến trình chạy ngầm (nếu có) vẫn hoạt động.",
      "info"
    );
  };

  closeBtn.onclick = hideDashboard;
  overlay.onclick = hideDashboard;

  window.showDashboard = showDashboard;

  document.addEventListener("click", closeAllActionMenus, true);
  document.body.appendChild(overlay);
  document.body.appendChild(container);

  logMessage("Dashboard đã được khởi tạo thành công.");
  refreshDashboard();
})();
