/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Web;
using System.Data;
using System.IO;
using System.Text;
using System.Data.SqlClient;
using System.Collections.Generic;
using Lucene.Net;

namespace btnet
{
	public class MyLucene
	{
        ///////////////////////////////////////////////////////////////////////
        static Lucene.Net.Documents.Document create_doc(int bug_id, int post_id, string text)
        {
           // btnet.Util.write_to_log("indexing " + Convert.ToString(bug_id));

            Lucene.Net.Documents.Document doc = new Lucene.Net.Documents.Document();

            doc.Add(new Lucene.Net.Documents.Field(
                "bg_id",
                Convert.ToString(bug_id),
                Lucene.Net.Documents.Field.Store.YES,
                Lucene.Net.Documents.Field.Index.UN_TOKENIZED));

            doc.Add(new Lucene.Net.Documents.Field(
                "bp_id",
                Convert.ToString(post_id),
                Lucene.Net.Documents.Field.Store.YES,
                Lucene.Net.Documents.Field.Index.UN_TOKENIZED));

            doc.Add(new Lucene.Net.Documents.Field(
                "text",
                new System.IO.StringReader(text)));

            return doc;
        }    

		public static void threadproc_build(object obj)
		{
			System.Web.HttpApplicationState app = (System.Web.HttpApplicationState)obj;

            string index_path = btnet.Util.get_lucene_index_folder();
            btnet.Util.write_to_log("started creating Lucene index using folder " + index_path);
            Lucene.Net.Analysis.Standard.StandardAnalyzer anal = new Lucene.Net.Analysis.Standard.StandardAnalyzer();
            Lucene.Net.Index.IndexWriter writer = new Lucene.Net.Index.IndexWriter(index_path, anal, true);

   			DbUtil dbutil = new DbUtil();
			DataSet ds = dbutil.get_dataset("select bg_id, bg_short_desc from bugs");

   			foreach (DataRow dr in ds.Tables[0].Rows)
            {
                writer.AddDocument(MyLucene.create_doc(
                    (int) dr["bg_id"], 
                    0, 
                    (string) dr["bg_short_desc"]));
            }

            ds = dbutil.get_dataset("select bp_bug, bp_id, isnull(bp_comment_search,bp_comment) [bp_comment] from bug_posts where bp_type <> 'update'");

            foreach (DataRow dr in ds.Tables[0].Rows)
            {
                writer.AddDocument(MyLucene.create_doc(
                    (int)dr["bp_bug"],
                    (int)dr["bp_id"],
                    (string)dr["bp_comment"]));
            }
            
            writer.Optimize();
            writer.Close();
            btnet.Util.write_to_log("done creating Lucene index");


		}




        public static void threadproc_update(object obj)
        {
            int bug_id = (int) obj;

            string index_path = btnet.Util.get_lucene_index_folder();
            btnet.Util.write_to_log("started updating Lucene index using folder " + index_path);
            Lucene.Net.Analysis.Standard.StandardAnalyzer anal = new Lucene.Net.Analysis.Standard.StandardAnalyzer();
            Lucene.Net.Index.IndexModifier modifier = new Lucene.Net.Index.IndexModifier(index_path, anal, false); 

            DbUtil dbutil = new DbUtil();
            DataSet ds = dbutil.get_dataset("select bg_id, bg_short_desc from bugs where bg_id = " + Convert.ToString(bug_id));
            
            modifier.DeleteDocuments(new Lucene.Net.Index.Term("bg_id",Convert.ToString(bug_id)));
            
            foreach (DataRow dr in ds.Tables[0].Rows)
            {
                modifier.AddDocument(MyLucene.create_doc(
                    (int)dr["bg_id"],
                    0,
                    (string)dr["bg_short_desc"]));
            }

            ds = dbutil.get_dataset("select bp_bug, bp_id, isnull(bp_comment_search,bp_comment) [bp_comment] from bug_posts where bp_type <> 'update' and bp_bug = " + Convert.ToString(bug_id));

            foreach (DataRow dr in ds.Tables[0].Rows)
            {
                modifier.AddDocument(MyLucene.create_doc(
                    (int)dr["bp_bug"],
                    (int)dr["bp_id"],
                    (string)dr["bp_comment"]));
            }

            modifier.Flush();
            modifier.Close();
            btnet.Util.write_to_log("done updating Lucene index");


        }

		public static void build_lucene_index(System.Web.HttpApplicationState app)
		{
			System.Threading.Thread thread = new System.Threading.Thread(threadproc_build);
			thread.Start(app);
		}


        public static void update_lucene_index(int bug_id)
        {
            System.Threading.Thread thread = new System.Threading.Thread(threadproc_update);
            thread.Start(bug_id);
        }

	}

}


