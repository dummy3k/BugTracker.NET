<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

    
String sql;
DbUtil dbutil;
Security security;
    

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
     //btnet.MyLucene.build_lucene_index(this.Application);
    // Response.Write("hello"); 
    //Response.End();
    
    //Util.do_not_cache(Response);
    dbutil = new DbUtil();
    security = new Security();
    security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);
    search();
}

    
        
void search()
{    
    Lucene.Net.Analysis.Standard.StandardAnalyzer anal = new Lucene.Net.Analysis.Standard.StandardAnalyzer();
    Lucene.Net.QueryParsers.QueryParser parser = new Lucene.Net.QueryParsers.QueryParser("text", anal);
    Lucene.Net.Search.Query query = parser.Parse(Request["query"]);
    string index_path = btnet.Util.get_lucene_index_folder();
    
    // search
    Lucene.Net.Search.Searcher searcher = new Lucene.Net.Search.IndexSearcher(index_path);
    Lucene.Net.Search.Hits hits = searcher.Search(query);

    //Response.Write("<p>searching for " + Request["query"] + "<p>");

    StringBuilder sb = new StringBuilder();
//    for (int i = 0; i < hits.Length(); i++)
//    {
//        Lucene.Net.Documents.Document doc = hits.Doc(i);
//        Response.Write("<br>hit score:");
//        Response.Write(Convert.ToString(hits.Score(i)));
//        Response.Write(", bg_id:");
//        Response.Write(doc.Get("bg_id"));
//    }

    string guid = Guid.NewGuid().ToString().Replace("-","");
    sb.Append(@"
create table #$GUID
(
temp_bg_id int,
temp_bp_id int,
temp_score float
)
");

    Dictionary<string, int> dict_already_seen_ids = new Dictionary<string, int>();
        
    for (int i = 0; i < hits.Length(); i++)
    {
        if (dict_already_seen_ids.Count < 100)
        {
            Lucene.Net.Documents.Document doc = hits.Doc(i);
            string bg_id = doc.Get("bg_id");
            if (!dict_already_seen_ids.ContainsKey(bg_id))
            {
                dict_already_seen_ids[bg_id] = 1; 
                sb.Append("insert into #");
                sb.Append(guid);
                sb.Append(" values(");
                sb.Append(bg_id);
                sb.Append(",");
                sb.Append(doc.Get("bp_id"));
                sb.Append(",");
                sb.Append(Convert.ToString((hits.Score(i))));
                sb.Append(")\n");
            }
        }
        else
        {
            break;
        }
    }
    searcher.Close();

    sb.Append(@"
select 'ffffff', bg_id [id], bg_short_desc [desc], ' ' [type], '' [comment/email],temp_score [score] 
from bugs 
inner join #$GUID t on t.temp_bg_id = bg_id and t.temp_bp_id = 0
where $ALTER_HERE 

union

select 'ffffff', bg_id [id], bg_short_desc [desc], bp_type, substring(bp_comment_search,1,100), temp_score [score] 
from bugs inner join #$GUID t on t.temp_bg_id = bg_id 
inner join bug_posts on temp_bp_id = bp_id  
where $ALTER_HERE

order by t.temp_score desc, bg_id desc

drop table #$GUID    

");

    string sql = sb.ToString().Replace("$GUID", guid);
    sql =  btnet.Util.alter_sql_per_project_permissions(sql, security);

    Session["bugs"] = dbutil.get_dataview(sql);
    Session["just_did_text_search"] = "yes";
    Response.Redirect("bugs.aspx");
}
        
</script>
