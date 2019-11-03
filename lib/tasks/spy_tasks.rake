namespace :spy do
  desc "Build dictionary file from given sources [path to unzipped FinnWordNet-2.0, path untarred FinnishTreeBank 3.0]."
  task :builddict, [:fwnpath, :ftbpath] do |task, args|
    spy = Spy::Spy.new
    spy.build_dictionary(args.fwnpath, args.ftbpath)
  end

  desc "Build language detector model."
  task :buildmodel, [:ficorpuspath, :etcorpuspath] do |task, args|
    spy = Spy::Spy.new
    spy.build_model(args.ficorpuspath, args.etcorpuspath)
  end
end
