
module Prick
  module Git
    # Return the origin of the repository
    def self.origin()
      Bash.command("git remote get-url origin").first
    end

    # Clone a repository
    def self.clone(url, directory = nil, branch: nil)
      branch_arg = branch ? "--branch #{branch}" : ""
      Bash.command("git clone --quiet #{branch_arg} '#{url}' #{directory}")
    end

    # Return the current commit id
    def self.id() Bash.command("git rev-parse HEAD").first end

    # Return true if the repository has no modified files or unresolved
    # conflicts. Requires the repository to have at least one commit
    def self.clean?(file = nil)
      re = file ? /^  #{file}(?: .*)?$/ : /^\?\?|!!/
      !Bash.command("git status --porcelain").any? { |l| l !~ re }
    end

    # Return true if the repo is synchronized with the remote
    def self.synchronized?()
      out = Bash.command "git rev-list --count --left-right 'HEAD...@{upstream}'"
      !(out.first =~ /^0\s+0$/).nil?
    end

    # Add files to the index
    def self.add(*files)
      files = Array(files).flatten
      Bash.command "git add #{files.join(" ")}"
    end

    # True if the file was added to the index
    def self.added?(file = nil)
      re = file ? /^[ACDMR]. #{file}$/ : /^[ACDMR]/
      Bash.command("git status --porcelain").any? { |l| l =~ re }
    end

    # Commit changes on the current branch"
    def self.commit(msg)
      out = Bash.command "git commit -m '#{msg}'", fail: false
      Bash.status == 0 or raise Bash.exception.exception(out.join("\n"))
    end

    # Pull changes from repository
    def self.pull
      Bash.command "git pull"
    end

    # Push change to repository
    def self.push
      Bash.command "git push --quiet --atomic"
    end

    # Access to tag methods
    def self.tag() Tag end

    # Access to branch methods
    def self.branch() Branch end

    # List files in repository
    def self.list() Bash.command("git ls-files") end

    module Tag
      # The associated commit ID of a tag
      def self.id(tag)
        tag && Bash.command("git rev-list -n 1 #{tag}").first
      end

      # True if tag exists
      def self.exist?(tag)
        tag && Bash.command?("git describe --tags #{tag}")
      end

      # Create tag
      def self.create(tag, id: nil)
        Bash.command "git tag '#{tag}' #{id}"
      end

      # Drop a tag
      def self.drop(tag)
        Bash.command "git tag -d '#{tag}'"
      end

      # Return list of all tags. Not in any particular order
      def self.list()
        Bash.command("git tag")
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
        stdout, stderr = Bash.command("git describe --tags #{id}", stderr: true, fail: false)
        if Bash.status != 0
          return nil if stderr.first =~ /No names found/
          raise Bash.exception
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
        Bash.command? "git show-ref --verify --quiet refs/heads/#{branch}"
      end

      def self.create(branch, id = nil, set_upstream: true)
        if set_upstream
          current = Git.branch.current
          Bash.command %(
            git checkout --quiet -b #{branch} #{id}
            git push --quiet --set-upstream origin #{branch}
            git checkout --quiet #{current}
          )
        else
          Bash.command "git branch #{branch} #{id}"
        end
      end

      def self.drop(branch)
        Bash.command "git branch -D #{branch}"
      end

      def self.list()
        Bash.command "git for-each-ref --format='%(refname:short)' refs/heads/*"
      end

      def self.current()
        Bash.command("git branch --show-current").first
      end

      def self.checkout(branch)
        Bash.command "git checkout --quiet #{branch}"
      end
    end
  end
end

__END__

    def self.changed?(file)
      Bash.command("git status --porcelain").any? { |l| l =~ /^.M #{file}$/ }
    end



    # Return true if `version` has an associated tag
    def self.tag?(version)
      !list_tags.grep(version.to_s).empty?
    end

    # Create version tag
    def self.create_tag(version, message: "Release #{version}", commit_id: nil)
      Bash.command "git tag -a 'v#{version}' -m '#{message}' #{commit_id}"
    end

    # Create a cancel-version tag
    def self.cancel_tag(version)
      create_tag("#{version}_cancelled", message: "Cancel #{version}", commit_id: tag_id(version))
    end

    def self.delete_tag(version, remote: false)
      Bash.command "git tag -d 'v#{version}'", fail: false
      Bash.command("git push --delete origin 'v#{version}'", fail: false) if remote
    end

    def self.tag_id(version)
      Bash.command("git rev-parse 'v#{version}^{}'").first
    end

    # Checkout a version tag as a detached head
    def self.checkout_tag(version)
        Bash.command "git checkout 'v#{version}'"
    end

    def self.list_tags(include_cancelled: false)
      tags = Bash.command("git tag")
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
      self.detached? ? nil : Bash.command("git rev-parse --abbrev-ref HEAD").first
    end

    # Check if branch exist
    def self.branch?(name)
      Bash.command("git show-ref --verify --quiet 'refs/heads/#{name}'", fail: false)
      Bash.status == 0
    end

    # Create a branch
    def self.create_branch(name)
      Bash.command "git branch #{name}"
    end

    # Rename a branch
    def self.rename_branch(from, to)
      Bash.command "git branch -m #{from} #{to}"
    end

    # Destroy branch
    def self.delete_branch(name)
      Bash.command "git branch -D #{name}", fail: false
    end

    # Check out branch
    def self.checkout_branch(name, create: false)
      if create
        Bash.command "git checkout -b #{name}"
      else
        Bash.command "git checkout #{name}"
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

      Bash.command "git merge --no-commit #{name}", fail: false

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
        Bash.command "git branch --format='%(refname:short)'"
      else
        Bash.command "git for-each-ref --format='%(refname:short)' refs/heads/*"
      end
    end

    # Add a file to the index of the current branch
    def self.add(*files)
      Array(files).flatten.each { |file|
        Dir.chdir(File.dirname(file)) {
          Bash.command "git add '#{File.basename(file)}'"
        }
      }
    end

    def self.changed?(file)
      Bash.command("git status --porcelain").any? { |l| l =~ /^.M #{file}$/ }
    end

    def self.added?(file)
      Bash.command("git status --porcelain").any? { |l| l =~ /^A. #{file}$/ }
    end

    # Return content of file in the given tag or branch. Defaults to HEAD
    def self.readlines(file, tag: nil, branch: nil)
      !(tag && branch) or raise Internal, "Can't use both tag: and branch: options"
      if tag
        Bash.command "git show v#{tag}:#{file}"
      else
        branch ||= "HEAD"
        Bash.command "git show #{branch}:#{file}"
      end.map { |l| "#{l}\n" }
    end

    # Return content of file as a String
    def self.read(file, tag: nil, branch: nil)
      !(tag && branch) or raise Internal, "Can't use both tag: and branch: options"
      if tag
        Bash.command "git show v#{tag}:#{file}"
      else
        branch ||= "HEAD"
        Bash.command "git show #{branch}:#{file}"
      end.join("\n") + "\n"
    end

    def self.rm(*files)
      Array(files).flatten.each { |file|
        Dir.chdir(File.dirname(file)) {
          Bash.command "git rm -f '#{File.basename(file)}'", fail: false
        }
      }
    end

    def self.rm_rf(*files)
      Array(files).flatten.each { |file|
        Dir.chdir(File.dirname(file)) {
          next if file == ".keep"
          Bash.command "git rm -rf '#{File.basename(file)}'", fail: false
        }
      }
    end

    # Commit changes on the current branch"
    def self.commit(msg)
      Bash.command "git commit -m '#{msg}'"
    end
  end
end

