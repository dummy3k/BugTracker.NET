using System;
using System.Collections.Generic;
using System.Web;
using Antlr.StringTemplate;
using System.Text;
using System.Diagnostics;

namespace btnet
{
    public class StringTemplates
    {
        private StringTemplateGroup mI18N;
        private StringTemplateGroup mCommon;

        string mLanguage;
        public String Language
        {
            get
            {
                return mLanguage;
            }
            private set
            {
                mLanguage = value;
            }
        }

        public StringTemplates()
        {
            Init("en");
        }

        public StringTemplates(HttpRequest Request)
        {
            Init(Request["lang"]);
        }

        private void Init(String language) {
            if (language == null)
            {
                language = "en";
            }
            language = language.ToLower();
            this.Language = language;

            String[] directories = new String[] {
                System.IO.Path.Combine(@"stringtemplates", language)};
            CommonGroupLoader groupLoader = new CommonGroupLoader(
                new DefaultGroupFactory(), null, Encoding.UTF8, directories);

            StringTemplateGroup.RegisterGroupLoader(groupLoader);

            mI18N = StringTemplateGroup.LoadGroup("templates");

            //mCommon = StringTemplateGroup.LoadGroup("common", mI18N);

            //FileSystemTemplateLoader commonLoader = new FileSystemTemplateLoader(
            //    System.IO.Path.Combine(@"stringtemplates", "common"), Encoding.UTF8, true);

            //IStringTemplateErrorListener blub = null;
            //mCommon = new StringTemplateGroup(
            //    "common",
            //    commonLoader,
            //    typeof(Antlr.StringTemplate.Language.DefaultTemplateLexer), new ConsoleErrorListener(), mI18N);
            ////mCommon.SetSuperGroup("templates");

            //mCommon = new StringTemplateGroup(System.IO.Path.Combine(@"stringtemplates", "common"));
            mCommon = new StringTemplateGroup("common", @"C:\Projekte\sis\BugTracker.NET\stringtemplates\common");
            mCommon.SuperGroup = mI18N;
        }

        public string getI18N(string name)
        {
            return mI18N.GetInstanceOf(name).ToString();
        }

        public string getCommon(String name)
        {
            return mCommon.GetInstanceOf(name).ToString();
        }

        public StringTemplateGroup Common
        {
            get
            {
                return mCommon;
            }
        }
    }
}
