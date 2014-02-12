using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;

using Mono.TextEditor;
using Mono.TextEditor.Highlighting;

using MonoDevelop.D.Highlighting;

namespace MonoDevelop.Vibe.Slim
{
	public class SlimTemplateSyntaxMode : SyntaxMode
	{
		private static SyntaxMode baseMode;

		public SlimTemplateSyntaxMode()
		{
			List<Match> list = new List<Match>();
			if (SlimTemplateSyntaxMode.baseMode == null)
			{
				ResourceStreamProvider resourceStreamProvider = new ResourceStreamProvider(typeof(SlimTemplateSyntaxMode).Assembly,  typeof(SlimTemplateSyntaxMode).Assembly.GetManifestResourceNames().First(s => s.Contains("SlimTemplateSyntaxMode")));
				using (Stream stream = resourceStreamProvider.Open())
				{
					SlimTemplateSyntaxMode.baseMode = SyntaxMode.Read(stream);
				}
			}
			this.rules = new List<Rule>(SlimTemplateSyntaxMode.baseMode.Rules);
			this.keywords = new List<Keywords>(SlimTemplateSyntaxMode.baseMode.Keywords);
			this.spans = SlimTemplateSyntaxMode.baseMode.Spans.Where(s => s.Begin.Pattern != "#").ToArray();
			list.AddRange(SlimTemplateSyntaxMode.baseMode.Matches);
			this.prevMarker = SlimTemplateSyntaxMode.baseMode.PrevMarker;
			this.SemanticRules = new List<SemanticRule> (SlimTemplateSyntaxMode.baseMode.SemanticRules);
			this.keywordTable = SlimTemplateSyntaxMode.baseMode.keywordTable;
			this.keywordTableIgnoreCase = SlimTemplateSyntaxMode.baseMode.keywordTableIgnoreCase;
			this.properties = SlimTemplateSyntaxMode.baseMode.Properties;
			list.Add(DSyntaxMode.workaroundMatchCtor("Number", "\t\t\t\t(?<!\\w)(0((x|X)[0-9a-fA-F_]+|(b|B)[0-1_]+)|([0-9]+[_0-9]*)[L|U|u|f|i]*)"));
			this.matches = list.ToArray();
		}

		private class InlineDSemRule : SemanticRule
		{
			private bool inUpdate = false;

			public override void Analyze(TextDocument doc, DocumentLine line, Chunk startChunk, int startOffset, int endOffset)
			{
			}
		}
	}
}