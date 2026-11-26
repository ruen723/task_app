class TasksController < ApplicationController
  def index
    @tasks = Current.user.tasks.order(:position)
  end

  def new
    @task = Current.user.tasks.build
  end

  def create
    user = Current.user
    saved = user.with_lock do
      @task = user.tasks.build(task_params)
      @task.position = user.tasks.maximum(:position).to_i + 1
      @task.save
    end

    if saved
      redirect_to tasks_path, status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @task = Current.user.tasks.find(params[:id])
  end

  def update
    user = Current.user
    saved = user.with_lock do
      @task = user.tasks.find(params[:id])
      @task.update(task_params)
    end

    if saved
      redirect_to tasks_path, status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    user = Current.user
    user.with_lock do
      task = user.tasks.find(params[:id])
      removed_position = task.position
      task.destroy!

      # Fill the vacant position first to preserve the unique index.
      user.tasks.where("position > ?", removed_position).order(:position).each do |following_task|
        following_task.update!(position: following_task.position - 1)
      end
    end

    redirect_to tasks_path, status: :see_other
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordInvalid
    redirect_to tasks_path, status: :see_other, alert: "タスクを削除できませんでした。"
  end

  private

  def task_params
    params.expect(task: %i[name planned_duration])
  end
end
