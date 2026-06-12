我完全理解你现在的处境了。没有 API、没有插件权限、无法触碰后台，甚至连跨部门沟通的渠道都被堵死了。在这个充满 DLP 监控和严格终端管控的内网环境里，浏览器的同源策略（SOP）就像一道绝对的铁闸。
我必须坦诚地告诉你一个技术现实：**在没有任何高权限配合的情况下，Web 安全的底层逻辑决定了，没有任何纯前端代码可以跨越域名（从你的工具页到 SNOW 页）去强行注入 JS。** 你摸索出的 Bookmarklet（书签）并不是一个“笨办法”，在这样极度受限的恶劣生态中，它是唯一能从客户端发起合法 JS 执行的**终极后门**。
既然我们只能走书签这条路，我们可以把这个“妥协的产物”包装成一个**体验极佳的企业级分发方案**。我们可以将你那台跑着 PHP 的服务器作为数据中枢，把书签变成一个“智能遥控器”。
### 1. 终极妥协方案：智能书签 + 剪贴板联动
核心痛点是书签里的代码是死的，而你要填的内容是活的。我们可以利用**剪贴板**作为两个毫不相干的网页之间的“数据桥梁”。
**工作流设计：**
 1. 同事在你的工具网页上填好内容，点击“生成”。
 2. 你的工具将这些内容打包成一段 **JSON 数据**，悄悄塞进同事的剪贴板，并自动打开 SNOW 的 Request 页面。
 3. 同事等待 SNOW 那个恶心的 onLoad 刷新完毕后，点击一下书签。
 4. 书签自动读取剪贴板的 JSON，瞬间调用 g_form.setValue() 把所有框填满。
#### 步骤 A：你的前端/PHP 页面代码
```html
<script>
async function generateAndJump() {
    // 1. 采集数据打包成 JSON
    const payload = {
        uid: document.getElementById('uid').value,
        desc: document.getElementById('desc').value,
        // 这里可以放各种 catalog 里的 variable 名字
    };
    
    const jsonString = JSON.stringify(payload);

    // 2. 写入剪贴板 (增加特定标识防止误读普通文本)
    const clipboardData = `[SNOW_AUTO]${jsonString}`;
    await navigator.clipboard.writeText(clipboardData);

    // 3. 跳转到 Request 提单页
    window.open("https://你的公司.service-now.com/com.glideapp.servicecatalog_cat_item_view.do?v=1&sysparm_id=那个Request的sys_id", '_blank');
}
</script>

```
#### 步骤 B：给同事用的“一键安装”书签代码
你不需要让同事去复制粘贴代码，只需在你的工具页顶部做一个大按钮，让他们**“把这个按钮拖拽到书签栏”**即可。
```html
<a href='javascript:(async function(){
    try {
        const text = await navigator.clipboard.readText();
        if(text.startsWith("[SNOW_AUTO]")) {
            const data = JSON.parse(text.replace("[SNOW_AUTO]", ""));
            // 调用 SNOW 的原生 API
            if(data.uid) g_form.setValue("你的uid变量名", data.uid);
            if(data.desc) g_form.setValue("你的desc变量名", data.desc);
            alert("预填成功！");
        } else {
            alert("剪贴板中没有发现预填数据，请先在工具页点击生成。");
        }
    } catch(e) {
        // 兼容策略：如果浏览器阻止直接读剪贴板，弹出输入框让同事 Ctrl+V
        const manual = prompt("自动读取剪贴板被拦截，请直接在此处 Ctrl+V 粘贴并回车：");
        if(manual && manual.startsWith("[SNOW_AUTO]")) {
            const data = JSON.parse(manual.replace("[SNOW_AUTO]", ""));
            if(data.uid) g_form.setValue("你的uid变量名", data.uid);
            if(data.desc) g_form.setValue("你的desc变量名", data.desc);
        }
    }
})();'>拖拽我到书签栏 (SNOW 自动填单)</a>

```
这种设计下，如果你以后要增加字段，你只需要改你服务器上的前端打包逻辑，**同事的书签永远不需要更新**，因为它只是一个无脑执行 JSON 的载体。
### 2. 最后确认：Request 的 URL 参数黑科技
在你彻底倒向书签方案之前，我想再确认一个极其微小但致命的技术细节。
Incident 和 Request (Service Catalog) 接收 URL 参数的格式是**完全不同**的。
 * **Incident** 用的是 sysparm_query=short_description=xxx。
 * **Request** 的变量（Variables）完全不吃这一套。在旧版 UI 中，必须使用 sysparm_变量名=值；而在 Service Portal (现代 UI) 中，URL 结构甚至直接变成了 &变量名=值。
**Service Portal 格式示例：**
https://实例名.service-now.com/sp?id=sc_cat_item&sys_id=请求项的ID&u_affected_user=E123456&description=测试内容
如果你之前在测试 Request 时，依然使用的是 sysparm_query 这个前缀，那么它之所以没填上，可能根本不是因为 onLoad 刷新给清空了，而是 SNOW 压根就没去解析那个错误的参数名。
你之前在测试 URL 传参给 Request 的时候，有尝试过直接在 URL 里写 &[你的Catalog变量名]=[值] 这种特定的 Catalog 参数格式吗？
