<input type=hidden name="new_page" id="new_page" runat="server" value="0">
<input type=hidden name="action" id="action" runat="server" value="">
<input type=hidden name="filter" id="filter" runat="server" value="">
<input type=hidden name="sort" id="sort" runat="server" value="-1">
<input type=hidden name="prev_sort" id="prev_sort" runat="server" value="-1">
<input type=hidden name="prev_dir" id="prev_dir" runat="server" value="ASC">

<script>
var enable_popups = <% Response.Write(Convert.ToString(security.user.enable_popups)); %>;
var asp_form_id = '<% Response.Write(Util.get_form_name()); %>';
</script>




