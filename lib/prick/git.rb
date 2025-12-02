
module Prick
  module Git
    # Return the origin of the repository
    def self.origin()
      Command.command("git remote get-url origin").first
    end

    # Clone a repository
    def self.clone(url, directory = nil, branch: nil)
      branch_arg = branch ? "--branch #{branch}" : ""
      Command.command("git clone --quiet #{branch_arg} '#{url}' #{directory}")
    end

    # Return the current commit id
    def self.id() Command.command("git rev-parse HEAD").first end

    # Return true if the repository has no modified files or unresolved
    # conflicts. Requires the repository to have at least one commit
    def self.clean?(file = nil)
      re = file ? /^  #{file}(?: .*)?$/ : /^\?\?|!!/
      !Command.command("git status --porcelain").any? { |l| l !~ re }
    end

    # Return true if the repo is synchronized with the remote
    def self.synchronized?()
      out = Command.command "git rev-list --count --left-right 'HEAD...@{upstream}'"
      !(out.first =~ /^0\s+0$/).nil?
    end

    # Add files to the index
    def self.add(*files)
      files = Array(files).flatten
      Command.command "git add #{files.join(" ")}"
    end

    # True if the file was added to the index
    def self.added?(file = nil)
      re = file ? /^[ACDMR]. #{file}$/ : /^[ACDMR]/
      Command.command("git status --porcelain").any? { |l| l =~ re }
    end

    # Commit changes on the current branch"
    def self.commit(msg)
      out = Command.command "git commit -m '#{msg}'", fail: false
      Command.status == 0 or raise Command.exception.exception(out.join("\n"))
    end

    # Pull changes from repository
    def self.pull
      Command.command "git pull"
    end

    # Push change to repository
    def self.push
      Command.command "git push --quiet --atomic"
    end

    # Access to tag methods
    def self.tag() Tag end

    # Access to branch methods
    def self.branch() Branch end

    # List files in repository
    def self.list() Command.command("git ls-files") end

    module Tag
      # The associated commit ID of a tag
      def self.id(tag)
        tag && Command.command("git rev-list -n 1 #{tag}").first
      end

      # True if tag exists
      def self.exist?(tag)
        tag && Command.command?("git describe --tags #{tag}")
      end

      # Create tag
      def self.create(tag, id: nil)
        Command.command "git tag '#{tag}' #{id}"
      end

      # Drop a tag
      def self.drop(tag)
        Command.command "git tag -d '#{tag}'"
      end

      # Return list of all tags. Not in any particular order
      def self.list()
        Command.command("git tag")
      end

      # Return the most recent tag before the given commit (defaults to the
      # last commit)
      def self.current(id = nil)
        describe_tag(id)&.first
      end

    private
      # Return a [tag, number-of-commits, commit-id] tuple of the most recent
      # tag. Return nil if no tag was found
      def self.describe_tag(id = nil)
        stdout, stderr = Command.command("git describe --tags #{id}", stderr: true, fail: false)
        if Command.status != 0
          return nil if stderr.first =~ /No names found/
          raise Command.exception
        end
        if stdout.first =~ /^(.*)-(\d+)-.([0-9a-f]{7})$/
          [$1, $2, $3]
        else
          [stdout.first, 0, nil]
        end
      end
    end

    module Branch
      def self.exist?(branch)
        Command.command? "git show-ref --verify --quiet refs/heads/#{branch}"
      end

      def self.create(branch, id = nil, set_upstream: true)
        if set_upstream
          current = Git.branch.current
          Command.command %(
            git checkout --quiet -b #{branch} #{id}
            git push --quiet --set-upstream origin #{branch}
            git checkout --quiet #{current}
          )
        else
          Command.command "git branch #{branch} #{id}"
        end
      end

      def self.drop(branch)
        Command.command "git branch -D #{branch}"
      end

      def self.list()
        Command.command "git for-each-ref --format='%(refname:short)' refs/heads/*"
      end

      def self.current()
        Command.command("git branch --show-current").first
      end

      def self.checkout(branch)
        Command.command "git checkout --quiet #{branch}"
      end
    end
  end
end

__END__

    def self.changed?(file)
      Command.command("git status --porcelain").any? { |l| l =~ /^.M #{file}$/ }
    end



    # Return true if `version` has an associated tag
    def self.tag?(version)
      !list_tags.grep(version.to_s).empty?
    end

    # Create version tag
    def self.create_tag(version, message: "Release #{version}", commit_id: nil)
      Command.command "git tag -a 'v#{version}' -m '#{message}' #{commit_id}"
    end

    # Create a cancel-version tag
    def self.cancel_tag(version)
      create_tag("#{version}_cancelled", message: "Cancel #{version}", commit_id: tag_id(version))
    end

    def self.delete_tag(version, remote: false)
      Command.command "git tag -d 'v#{version}'", fail: false
      Command.command("git push --delete origin 'v#{version}'", fail: false) if remote
    end

    def self.tag_id(version)
      Command.command("git rev-parse 'v#{version}^{}'").first
    end

    # Checkout a version tag as a detached head
    def self.checkout_tag(version)
        Command.command "git checkout 'v#{version}'"
    end

    def self.list_tags(include_cancelled: false)
      tags = Command.command("git tag")
      if !include_cancelled
        cancelled = tags.select { |tag| tag =~ /_cancelled$/ }
        for cancel_tag in cancelled
          tags.delete(cancel_tag)
          tags.delete(cancel_tag.sub(/_cancelled$/, ""))
        end
      end
      tags.map { |tag| tag = tag[1..-1] }
    end

    # Name of the current branch. This is nil if on a tag ("detached HEAD")
    def self.current_branch()
      self.detached? ? nil : Command.command("git rev-parse --abbrev-ref HEAD").first
    end

    # Check if branch exist
    def self.branch?(name)
      Command.command("git show-ref --verify --quiet 'refs/heads/#{name}'", fail: false)
      Command.status == 0
    end

    # Create a branch
    def self.create_branch(name)
      Command.command "git branch #{name}"
    end

    # Rename a branch
    def self.rename_branch(from, to)
      Command.command "git branch -m #{from} #{to}"
    end

    # Destroy branch
    def self.delete_branch(name)
      Command.command "git branch -D #{name}", fail: false
    end

    # Check out branch
    def self.checkout_branch(name, create: false)
      if create
        Command.command "git checkout -b #{name}"
      else
        Command.command "git checkout #{name}"
      end
    end

    # Merge a branch
    def self.merge_branch(name, exclude_files: [], fail: false)
      # Save content of excluded files
      files = {}
      exclude_files.each { |file|
        next if !File.exist?(file)
        files[file] = File.readlines(file)
      }

      Command.command "git merge --no-commit #{name}", fail: false

      # Restore excluded files
      files.each { |path, content|
        File.open(path, "w") { |file| file.puts(content) }
        # Resolve git unmerged status
        Git.add(path)
      }

      # TODO Detect outstanding merges
    end

    def self.merge_tag(name, exclude_files: [], fail: false)
      merge_branch(name, exclude_files: exclude_files, fail: fail)
    end

    # List branches. Detached head "branches" are ignored unless :detached_head is true
    def self.list_branches(detached_head: false)
      if detached_head
        Command.command "git branch --format='%(refname:short)'"
      else
        Command.command "git for-each-ref --format='%(refname:short)' refs/heads/*"
      end
    end

    # Add a file to the index of the current branch
    def self.add(*files)
      Array(files).flatten.each { |file|
        Dir.chdir(File.dirname(file)) {
          Command.command "git add '#{File.basename(file)}'"
        }
      }
    end

    def self.changed?(file)
      Command.command("git status --porcelain").any? { |l| l =~ /^.M #{file}$/ }
    end

    def self.added?(file)
      Command.command("git status --porcelain").any? { |l| l =~ /^A. #{file}$/ }
    end

    # Return content of file in the given tag or branch. Defaults to HEAD
    def self.readlines(file, tag: nil, branch: nil)
      !(tag && branch) or raise Internal, "Can't use both tag: and branch: options"
      if tag
        Command.command "git show v#{tag}:#{file}"
      else
        branch ||= "HEAD"
        Command.command "git show #{branch}:#{file}"
      end.map { |l| "#{l}\n" }
    end

    # Return content of file as a String
    def self.read(file, tag: nil, branch: nil)
      !(tag && branch) or raise Internal, "Can't use both tag: and branch: options"
      if tag
        Command.command "git show v#{tag}:#{file}"
      else
        branch ||= "HEAD"
        Command.command "git show #{branch}:#{file}"
      end.join("\n") + "\n"
    end

    def self.rm(*files)
      Array(files).flatten.each { |file|
        Dir.chdir(File.dirname(file)) {
          Command.command "git rm -f '#{File.basename(file)}'", fail: false
        }
      }
    end

    def self.rm_rf(*files)
      Array(files).flatten.each { |file|
        Dir.chdir(File.dirname(file)) {
          next if file == ".keep"
          Command.command "git rm -rf '#{File.basename(file)}'", fail: false
        }
      }
    end

    # Commit changes on the current branch"
    def self.commit(msg)
      Command.command "git commit -m '#{msg}'"
    end
  end
end

